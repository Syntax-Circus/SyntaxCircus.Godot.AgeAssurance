"""Build a local versioned addon distribution; never publishes to a remote."""
import argparse
import hashlib
import json
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = 'SyntaxCircus.Godot.AgeAssurance'
STABLE_VERSION = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')

def package(root=ROOT, source_only=False, version=None, output=None, source_commit=None):
    root = pathlib.Path(root).resolve()
    cfg_name = 'addons/syntaxcircus_age_assurance/plugin.cfg'
    cfg = (root/cfg_name).read_text(encoding='utf-8-sig')
    declarations = re.findall(r'(?m)^version="([^"\r\n]+)"[ \t]*$',cfg)
    if len(declarations) != 1: raise ValueError('plugin.cfg must contain one version')
    version = declarations[0] if version is None else version
    if not isinstance(version,str) or not STABLE_VERSION.fullmatch(version):
        raise ValueError('Version must be stable X.Y.Z without a v prefix')
    if source_commit is not None and not re.fullmatch(r'[0-9a-fA-F]{40}',source_commit):
        raise ValueError('Source commit must be a full Git SHA')
    output = pathlib.Path(output).resolve() if output is not None else root/'dist'
    for source in ('addons','ios','scripts','tests'):
        if output == root/source or root/source in output.parents:
            raise ValueError('Output must be outside package source directories')
    out = output/version
    if out.exists(): raise FileExistsError('Release directory already exists: '+str(out))
    payload = {}
    for path in (root / 'addons').rglob('*'):
        if path.is_file() and path.suffix not in ('.uid', '.import'):
            payload[path.relative_to(root).as_posix()] = path.read_bytes()
    payload[cfg_name] = re.sub(r'(?m)^version="[^"\r\n]+"[ \t]*$',lambda _: 'version="'+version+'"',cfg).encode('utf-8')
    for path in (root / 'ios').glob('*'):
        if path.is_file(): payload['third_party/syntaxcircus_age_assurance/ios/' + path.name] = path.read_bytes()
    if not source_only:
        for flavor in ('debug', 'release'):
            path = root / 'android/plugin/build/outputs/aar' / ('plugin-' + flavor + '.aar')
            with zipfile.ZipFile(path) as aar:
                if 'classes.jar' not in aar.namelist(): raise ValueError('Invalid Android bridge archive')
            payload['addons/syntaxcircus_age_assurance/bin/' + flavor + '/SyntaxCircusAgeAssurance-' + flavor + '.aar'] = path.read_bytes()
    payload['third_party/syntaxcircus_age_assurance/README.md'] = (root / 'README.md').read_bytes()
    payload['third_party/syntaxcircus_age_assurance/LICENSE.txt'] = (root / 'LICENSE.txt').read_bytes()
    payload['third_party/syntaxcircus_age_assurance/consumer.py'] = (root / 'scripts/consumer.py').read_bytes()
    archive_name = LIBRARY+'-'+version+'.zip'
    manifest = {'library': LIBRARY, 'version': version,
                'source': 'https://github.com/Syntax-Circus/'+LIBRARY,
                'release': 'https://github.com/Syntax-Circus/'+LIBRARY+'/releases/tag/v'+version,
                'archive': archive_name, 'license': 'MIT', 'godot': '4.7.2',
                'source_only': source_only, 'files': [{'path': name, 'sha256': hashlib.sha256(data).hexdigest()}
                    for name, data in sorted(payload.items())]}
    if source_commit is not None: manifest['source_commit'] = source_commit
    out.mkdir(parents=True, exist_ok=False)
    archive = out/archive_name
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as target:
        for name, data in sorted(payload.items()): target.writestr(name, data)
    manifest['archive_sha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return out

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-only', action='store_true', help='Testing only; mobile release guards reject this distribution')
    parser.add_argument('--root', type=pathlib.Path, default=ROOT)
    parser.add_argument('--version', help='Stable X.Y.Z; defaults to plugin.cfg')
    parser.add_argument('--output', type=pathlib.Path, help='Release output directory; defaults to ROOT/dist')
    parser.add_argument('--source-commit', help='Full commit SHA of the tagged source')
    args = parser.parse_args()
    print(package(args.root,args.source_only,args.version,args.output,args.source_commit))
