"""Consumer-side vendoring, mobile preflight and signed-artifact age-assurance guards."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import zipfile

LIBRARY = 'SyntaxCircus.Godot.AgeAssurance'
PREFIX = 'addons/syntaxcircus_age_assurance/'
THIRD_PARTY = 'third_party/syntaxcircus_age_assurance/'
ENTITLEMENT = 'com.apple.developer.declared-age-range'

def safe_path(name):
    path = pathlib.PurePosixPath(name)
    if '\\' in name or ':' in name or '..' in path.parts or not (name.startswith(PREFIX) or name.startswith(THIRD_PARTY)):
        raise ValueError('Invalid age assurance payload path')
    return path

def read_manifest(path):
    manifest = json.loads(path.read_text(encoding='utf-8-sig'))
    if manifest.get('library') != LIBRARY or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',manifest.get('version','')):
        raise ValueError('Invalid age assurance manifest identity')
    names = [entry['path'] for entry in manifest['files']]
    if len(names) != len(set(names)): raise ValueError('Duplicate age assurance payload path')
    for name in names: safe_path(name)
    return manifest

def vendor(release, app):
    release, app = pathlib.Path(release), pathlib.Path(app)
    manifest_path = release/'manifest.json'
    manifest = read_manifest(manifest_path)
    with zipfile.ZipFile(release/(LIBRARY+'-'+manifest['version']+'.zip')) as archive:
        if set(archive.namelist()) != {entry['path'] for entry in manifest['files']}:
            raise ValueError('Age assurance archive/manifest mismatch')
        payload = {entry['path']:archive.read(entry['path']) for entry in manifest['files']}
    for entry in manifest['files']:
        if hashlib.sha256(payload[entry['path']]).hexdigest() != entry['sha256']:
            raise ValueError('Age assurance payload hash mismatch')
    # Validate everything before replacing any file. Do not delete consumer files.
    for name, data in payload.items():
        target = app.joinpath(*safe_path(name).parts)
        target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
    target = app/THIRD_PARTY/'manifest.json'
    target.write_bytes(manifest_path.read_bytes())

def verify_manifest(app, mobile_release=False):
    app = pathlib.Path(app)
    manifest = read_manifest(app/THIRD_PARTY/'manifest.json')
    if mobile_release and manifest.get('source_only',False): raise ValueError('Mobile export cannot use a source-only age assurance release')
    known = set()
    for entry in manifest['files']:
        file = app.joinpath(*safe_path(entry['path']).parts)
        if hashlib.sha256(file.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('Age assurance vendored hash mismatch: '+entry['path'])
        known.add(entry['path'])
    for file in (app/PREFIX).rglob('*'):
        if file.is_file() and file.suffix not in ('.uid','.import') and file.relative_to(app).as_posix() not in known:
            raise ValueError('Unmanifested age assurance addon file')

def check_native(app, platform):
    app = pathlib.Path(app)
    verify_manifest(app,mobile_release=True)
    if platform == 'android':
        for flavor in ('debug','release'):
            path = app/PREFIX/'bin'/flavor/('SyntaxCircusAgeAssurance-'+flavor+'.aar')
            with zipfile.ZipFile(path) as archive:
                if 'classes.jar' not in archive.namelist(): raise ValueError('Age assurance Android bridge is invalid')
    elif platform == 'ios':
        path = app/'ios/plugins/age_assurance/SyntaxCircusAgeAssurance.a'
        if not path.read_bytes().startswith(b'!<arch>\n'): raise ValueError('Age assurance iOS bridge is invalid')

def prepare_ios(app):
    app = pathlib.Path(app)
    check_native(app,'ios')
    preset = app/'export_presets.cfg'
    text = preset.read_text(encoding='utf-8-sig')
    match = re.search(r'(?m)^\[preset\.(\d+)\]\s*\nname="[^"]*"\s*\nplatform="iOS"',text)
    if not match: raise ValueError('iOS export preset missing')
    section = re.search(r'(?ms)^\[preset\.'+match[1]+r'\.options\]\s*\n(.*?)(?=^\[|\Z)',text)
    if not section: raise ValueError('iOS options missing')
    body = section[1]
    existing = re.search(r'(?m)^entitlements/additional=(.*)$',body)
    xml = json.loads(existing[1]) if existing else ''
    wrapped = plistlib.loads(('<plist version="1.0"><dict>'+xml+'</dict></plist>').encode()) if xml else {}
    wrapped[ENTITLEMENT] = True
    document = plistlib.dumps(wrapped).decode()
    fragment = document.split('<dict>',1)[1].rsplit('</dict>',1)[0].strip()
    line = 'entitlements/additional='+json.dumps(fragment)
    body = re.sub(r'(?m)^entitlements/additional=.*$',lambda _:line,body) if existing else body+line+'\n'
    line = 'plugins/SyntaxCircusAgeAssurance=true'
    body = re.sub(r'(?m)^plugins/SyntaxCircusAgeAssurance=.*$',line,body) if re.search(r'(?m)^plugins/SyntaxCircusAgeAssurance=',body) else body+line+'\n'
    preset.write_text(text[:section.start(1)]+body+text[section.end(1):],encoding='utf-8')

def verify_entitlements(entitlements):
    if entitlements.get(ENTITLEMENT) is not True: raise ValueError('Declared Age Range entitlement missing')

def verify_android_bytes(dex):
    if b'SyntaxCircusAgeAssurance' not in dex or b'AgeSignalsManager' not in dex:
        raise ValueError('Android artifact missing age assurance bridge or Google SDK')

def verify_android(artifact, manifest):
    text = pathlib.Path(manifest).read_text(encoding='utf-8')
    if 'org.godotengine.plugin.v2.SyntaxCircusAgeAssurance' not in text:
        raise ValueError('Android manifest missing age assurance plugin')
    with zipfile.ZipFile(artifact) as archive:
        verify_android_bytes(b''.join(archive.read(name) for name in archive.namelist() if name.endswith('.dex')))

def verify_ios(bundle):
    bundle = pathlib.Path(bundle)
    info = plistlib.loads((bundle/'Info.plist').read_bytes())
    if b'SyntaxCircusAgeAssurance' not in (bundle/info['CFBundleExecutable']).read_bytes():
        raise ValueError('iOS executable missing age assurance bridge')
    raw = subprocess.check_output(['codesign','-d','--entitlements',':-',str(bundle)],stderr=subprocess.PIPE)
    verify_entitlements(plistlib.loads(raw))
    raw = subprocess.check_output(['security','cms','-D','-i',str(bundle/'embedded.mobileprovision')])
    verify_entitlements(plistlib.loads(raw).get('Entitlements',{}))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['vendor','check','prepare-ios','verify-android','verify-ios'])
    parser.add_argument('path',type=pathlib.Path)
    parser.add_argument('--app',type=pathlib.Path)
    parser.add_argument('--platform',choices=['android','ios'])
    parser.add_argument('--manifest')
    args=parser.parse_args()
    if args.command=='vendor':
        if not args.app: parser.error('vendor requires --app')
        vendor(args.path,args.app)
    elif args.command=='check':
        if not args.platform: parser.error('check requires --platform')
        check_native(args.path,args.platform)
    elif args.command=='prepare-ios': prepare_ios(args.path)
    elif args.command=='verify-android':
        if not args.manifest: parser.error('verify-android requires --manifest')
        verify_android(args.path,args.manifest)
    else: verify_ios(args.path)
    print('Age assurance '+args.command+' passed')

if __name__=='__main__': main()
