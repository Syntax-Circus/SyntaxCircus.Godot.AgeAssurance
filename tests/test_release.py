"""Local release contract: stamped versions, exact hashes, provenance and safe output."""
import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('age_release', ROOT/'scripts/release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)/'source'
        addon = self.root/'addons/syntaxcircus_age_assurance'
        addon.mkdir(parents=True)
        (addon/'plugin.cfg').write_text('[plugin]\nversion="0.1.0"\n')
        (addon/'age_provider.gd').write_text('extends RefCounted\n')
        (addon/'age_provider.gd.uid').write_text('editor cache')
        (self.root/'ios').mkdir()
        (self.root/'ios/AgeAssurance.swift').write_text('// native source')
        (self.root/'scripts').mkdir()
        for name in ('README.md','LICENSE.txt','scripts/consumer.py'):
            (self.root/name).write_text('fixture')
        for flavor in ('debug','release'):
            aar=self.root/('android/plugin/build/outputs/aar/plugin-'+flavor+'.aar')
            aar.parent.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(aar,'w') as archive: archive.writestr('classes.jar',b'fixture')
        self.output=pathlib.Path(self.temp.name)/'output'

    def test_tag_version_is_stamped_without_changing_source(self):
        original=(self.root/'addons/syntaxcircus_age_assurance/plugin.cfg').read_bytes()
        out=release.package(self.root,version='1.2.3',output=self.output,source_commit='a'*40)
        manifest=json.loads((out/'manifest.json').read_text())
        self.assertEqual(manifest['version'],'1.2.3')
        self.assertEqual(manifest['source_commit'],'a'*40)
        self.assertEqual(manifest['archive'],'SyntaxCircus.Godot.AgeAssurance-1.2.3.zip')
        archive=out/manifest['archive']
        self.assertEqual(manifest['archive_sha256'],hashlib.sha256(archive.read_bytes()).hexdigest())
        with zipfile.ZipFile(archive) as payload:
            self.assertIn(b'version="1.2.3"',payload.read('addons/syntaxcircus_age_assurance/plugin.cfg'))
            self.assertEqual(set(payload.namelist()),{entry['path'] for entry in manifest['files']})
            for entry in manifest['files']:
                self.assertFalse(entry['path'].endswith('.uid'))
                self.assertEqual(entry['sha256'],hashlib.sha256(payload.read(entry['path'])).hexdigest())
        self.assertEqual(original,(self.root/'addons/syntaxcircus_age_assurance/plugin.cfg').read_bytes())

    def test_invalid_versions_and_output_inside_source_are_rejected(self):
        for version in ('../escape','v1.2.3','01.2.3','1.2','1.2.3-preview.1'):
            with self.subTest(version=version),self.assertRaises(ValueError):
                release.package(self.root,version=version,output=self.output)
        with self.assertRaises(ValueError):
            release.package(self.root,version='1.2.3',output=self.root/'addons/output')
        with self.assertRaises(ValueError):
            release.package(self.root,version='1.2.3',output=self.output,source_commit='bad')

    def test_existing_release_is_not_overwritten(self):
        release.package(self.root,version='1.2.3',output=self.output)
        with self.assertRaises(FileExistsError): release.package(self.root,version='1.2.3',output=self.output)

    def test_mobile_package_requires_both_built_aars(self):
        (self.root/'android/plugin/build/outputs/aar/plugin-release.aar').unlink()
        with self.assertRaises(FileNotFoundError): release.package(self.root,version='1.2.3',output=self.output)
        self.assertFalse(self.output.exists())

if __name__=='__main__': unittest.main()
