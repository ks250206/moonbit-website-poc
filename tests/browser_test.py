"""Browser integration tests; defaults to a real HTTP server at a project subpath.

LUMEN_OFFLINE_TEST=1 uses an in-memory document and the same compiled Wasm
bytes for restricted environments where browser navigation is disallowed.
Only fetch/history are substituted in that mode; URL tests run in normal CI.
"""
from __future__ import annotations
import base64
import functools
import http.server
import os
from pathlib import Path
import re
import tempfile
import threading
import unittest
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'dist'
ARTIFACTS = ROOT / 'artifacts'
OFFLINE = os.environ.get('LUMEN_OFFLINE_TEST') == '1'

class BrowserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ARTIFACTS.mkdir(exist_ok=True)
        cls.p = sync_playwright().start()
        executable = os.environ.get('CHROMIUM_PATH')
        cls.browser = cls.p.chromium.launch(
            headless=True, executable_path=executable, args=['--no-sandbox'])
        cls.tmp = tempfile.TemporaryDirectory()
        Path(cls.tmp.name, 'moonbit-website-poc').symlink_to(DIST, target_is_directory=True)
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=cls.tmp.name)
        cls.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f'http://127.0.0.1:{cls.server.server_port}/moonbit-website-poc/'

    @classmethod
    def tearDownClass(cls):
        cls.browser.close(); cls.p.stop()
        cls.server.shutdown(); cls.server.server_close(); cls.tmp.cleanup()

    def setUp(self):
        self.context = self.browser.new_context(viewport={'width':1440,'height':1100})
        self.page = self.context.new_page()
        self.errors = []
        self.page.on('pageerror', lambda error: self.errors.append(str(error)))

    def tearDown(self):
        self.context.close()
        self.assertEqual(self.errors, [], 'uncaught JavaScript errors')

    def load(self, query='', fail=False):
        if OFFLINE:
            html = re.sub(r'<link[^>]*>', '', (DIST/'index.html').read_text())
            html = re.sub(r'<script.*?</script>', '', html)
            html = html.replace('</head>', '<base href="https://lumen.example/moonbit-website-poc/">'
                + '<style>' + (DIST/'styles.css').read_text() + '</style></head>')
            self.page.set_content(html)
            self.page.evaluate('''({encoded,fail}) => {
                const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
                globalThis.fetch=async()=>new Response(bytes,{status:fail?404:200});
                history.replaceState=()=>{};
            }''', {'encoded':base64.b64encode((DIST/'engine.wasm').read_bytes()).decode(),'fail':fail})
            self.page.add_script_tag(type='module', content=(DIST/'app.js').read_text())
        else:
            if fail:
                self.page.route('**/engine.wasm', lambda route: route.fulfill(status=404,body='Not found'))
            self.page.goto(self.url + query)
        self.page.wait_for_selector('#app[data-ready="error"' + ']' if fail else '#app[data-ready="true"]')
        self.page.evaluate('() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))')

    def fast_solve(self, mobile=False):
        self.page.locator('#speed').fill('5')
        self.page.locator('#mobile-play' if mobile else '#play').click()
        self.page.wait_for_function("document.getElementById('status').textContent === '最短経路が見つかりました'",timeout=15000)

    def test_controls_and_finished_path(self):
        self.load()
        self.page.locator('#step').click()
        self.assertEqual(self.page.locator('#visited').inner_text(), '1 / 651')
        self.page.locator('#reset').click()
        self.page.locator('#play').click()
        self.page.wait_for_timeout(300)
        self.page.locator('#play').click()
        count = self.page.locator('#visited').inner_text()
        self.page.wait_for_timeout(200)
        self.assertEqual(self.page.locator('#visited').inner_text(), count)
        self.assertNotEqual(count, '0 / 651')
        self.fast_solve()
        self.assertEqual(self.page.locator('#cost').inner_text(), '60')
        self.assertIn('60 歩', self.page.locator('#path-info').inner_text())
        self.page.screenshot(path=str(ARTIFACTS/'desktop.png'),full_page=True)
        self.page.locator('#reset').click()
        self.assertEqual(self.page.locator('#cost').inner_text(), '—')
        self.assertEqual(self.page.locator('#visited').inner_text(), '0 / 651')

    def test_seed_and_settings(self):
        self.load()
        before = self.page.locator('#maze').evaluate('(c)=>c.toDataURL()')
        self.page.locator('#generate').click()
        self.assertEqual(self.page.locator('#maze').evaluate('(c)=>c.toDataURL()'),before)
        self.page.locator('#size').select_option('19')
        self.page.locator('#algorithm').select_option('1')
        self.page.locator('#weighted').check(force=True)
        self.page.locator('#seed').fill('42')
        self.page.locator('#generate').click()
        self.assertEqual(self.page.locator('#grid-label').inner_text(), '19 × 13')
        self.fast_solve()
        self.assertGreater(int(self.page.locator('#cost').inner_text()),0)
        self.page.locator('#shuffle').click()
        self.assertNotEqual(self.page.locator('#seed').input_value(),'42')
        self.assertEqual(self.page.locator('#visited').inner_text(),'0 / 247')

    def test_endpoints_start_equals_goal(self):
        self.load()
        stage=self.page.locator('#overlay').bounding_box()
        assert stage
        x=stage['x']+stage['width']*1.5/33
        y=stage['y']+stage['height']*1.5/23
        self.page.locator('#endpoint').select_option('2')
        self.page.mouse.click(x,y)
        self.fast_solve()
        self.assertEqual(self.page.locator('#cost').inner_text(),'0')
        self.assertIn('0 歩',self.page.locator('#path-info').inner_text())

    def test_regenerate_while_running_and_large_grid(self):
        self.load()
        self.page.locator('#play').click()
        self.page.locator('#size').select_option('95')
        self.page.locator('#generate').click()
        self.assertEqual(self.page.locator('#app').get_attribute('data-running'),'false')
        self.page.wait_for_timeout(100)
        self.assertEqual(self.page.locator('#visited').inner_text(),'0 / 5985')
        self.fast_solve()
        self.assertGreater(int(self.page.locator('#cost').inner_text()),0)

    def test_mobile_transport_and_layout(self):
        self.page.set_viewport_size({'width':390,'height':844})
        self.load()
        self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth > innerWidth'))
        self.assertTrue(self.page.locator('#mobile-play').is_visible())
        self.fast_solve(mobile=True)
        self.page.screenshot(path=str(ARTIFACTS/'mobile.png'),full_page=True)
        for width in [320,768,1024]:
            self.page.set_viewport_size({'width':width,'height':900})
            self.page.wait_for_timeout(80)
            self.assertFalse(self.page.evaluate('document.documentElement.scrollWidth > innerWidth'))
        self.page.set_viewport_size({'width':390,'height':844})
        self.page.locator('#mobile-reset').click()
        self.assertEqual(self.page.locator('#visited').inner_text(),'0 / 651')

    def test_keyboard(self):
        self.load()
        self.page.locator('h1').click()
        self.page.keyboard.press('Space')
        self.page.wait_for_timeout(150)
        self.page.keyboard.press('Space')
        self.assertEqual(self.page.locator('#app').get_attribute('data-running'),'false')
        self.page.keyboard.press('r')
        self.assertEqual(self.page.locator('#visited').inner_text(),'0 / 651')
        self.page.keyboard.press('ArrowRight')
        self.assertEqual(self.page.locator('#visited').inner_text(),'1 / 651')

    def test_error_is_visible(self):
        self.load(fail=True)
        self.assertIn('読み込めません',self.page.locator('#status').inner_text())
        self.assertIn('HTTP 404',self.page.locator('#notice').inner_text())
        self.assertTrue(self.page.locator('#play').is_disabled())

    @unittest.skipIf(OFFLINE,'URL restoration requires real HTTP navigation; exercised in CI')
    def test_url_restoration_and_project_subpath(self):
        self.load('?seed=42&size=19&algorithm=1&loops=35&weighted=1&start=7&goal=91')
        self.assertEqual(self.page.locator('#seed').input_value(),'42')
        self.assertEqual(self.page.locator('#size').input_value(),'19')
        self.assertTrue(self.page.locator('#weighted').is_checked())
        self.fast_solve()
        cost=self.page.locator('#cost').inner_text()
        self.page.reload()
        self.page.wait_for_selector('#app[data-ready="true"]')
        self.fast_solve()
        self.assertEqual(self.page.locator('#cost').inner_text(),cost)
        self.assertIn('/moonbit-website-poc/', self.page.url)

    def test_reduced_motion(self):
        self.page.emulate_media(reduced_motion='reduce')
        self.load(); self.fast_solve()
        self.assertEqual(self.page.locator('#cost').inner_text(),'60')

if __name__ == '__main__':
    unittest.main(verbosity=2)
