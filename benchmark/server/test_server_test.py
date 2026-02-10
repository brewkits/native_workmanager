import unittest
import requests
import time
import threading
import os
import sys

# Add path to import test_server.py
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from test_server import app, setup_files, FILES_DIR

# Run test server on different port to avoid conflicts if main server is running
TEST_PORT = 8081
BASE_URL = f"http://127.0.0.1:{TEST_PORT}"

class TestServerTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Initialize Server in a separate thread before running tests"""
        # Ensure dummy files are created
        setup_files()

        # Run Flask app
        cls.server_thread = threading.Thread(
            target=app.run,
            kwargs={'host': '127.0.0.1', 'port': TEST_PORT, 'threaded': True}
        )
        cls.server_thread.daemon = True
        cls.server_thread.start()

        # Wait a moment for server to start
        time.sleep(1)
        print(f"\n🚀 Test Environment Started on {BASE_URL}")

    def test_index_health_check(self):
        """Check if server is alive"""
        response = requests.get(f"{BASE_URL}/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("Running", response.text)

    def test_echo_json(self):
        """Check if /echo endpoint returns the correct JSON sent"""
        payload = {'key': 'value', 'list': [1, 2, 3]}
        response = requests.post(f"{BASE_URL}/echo", json=payload)

        self.assertEqual(response.status_code, 200)
        json_resp = response.json()
        self.assertEqual(json_resp['json'], payload)  # Server must return exact payload
        self.assertEqual(json_resp['method'], 'POST')

    def test_status_code_simulation(self):
        """Check error simulation (403, 500)"""
        response = requests.get(f"{BASE_URL}/status/403")
        self.assertEqual(response.status_code, 403)

        response = requests.get(f"{BASE_URL}/status/500")
        self.assertEqual(response.status_code, 500)

    def test_upload_simulation(self):
        """Check multipart file upload"""
        # Simulate file upload
        files = {'file': ('test.txt', b'Hello World Content')}
        data = {'user_id': '123'}

        start_time = time.time()
        response = requests.post(f"{BASE_URL}/upload", files=files, data=data)
        duration = time.time() - start_time

        self.assertEqual(response.status_code, 200)
        resp_json = response.json()

        # Check returned content
        self.assertEqual(resp_json['filename'], 'test.txt')
        self.assertEqual(resp_json['form_fields']['user_id'], '123')

        # Check simulated delay (in test_server.py we set sleep(1))
        # Duration must be >= 1s
        self.assertGreaterEqual(duration, 1.0)

    def test_download_resume_capability(self):
        """
        IMPORTANT: Check Range Header (Resume) feature.
        Native Worker needs this to resume downloads.
        """
        # Download first 10 bytes
        headers = {'Range': 'bytes=0-9'}
        response = requests.get(f"{BASE_URL}/files/1MB.zip", headers=headers)

        # Server must return 206 Partial Content
        self.assertEqual(response.status_code, 206)
        self.assertEqual(len(response.content), 10)
        self.assertIn("Content-Range", response.headers)

    def test_download_throttling_10MB(self):
        """
        Check slow network simulation.
        10MB.zip file is configured with 2.0s delay in test_server.py
        """
        start_time = time.time()

        # Download file (stream=True to avoid loading all into test client RAM)
        with requests.get(f"{BASE_URL}/files/10MB.zip", stream=True) as r:
            r.raise_for_status()
            for _ in r.iter_content(chunk_size=8192):
                pass  # Just read everything to measure time

        duration = time.time() - start_time

        # Download time should be approximately 2.0s (allow for network margin)
        print(f"Download 10MB took: {duration:.2f}s (Target: ~2.0s)")
        self.assertGreaterEqual(duration, 1.8)

    def test_redirect_handling(self):
        """Check if server redirects correctly"""
        # By default requests will follow redirects
        response = requests.get(f"{BASE_URL}/redirect-to?url=/echo&status=302")
        self.assertEqual(response.status_code, 200)
        # After redirect, it will go to /echo and return JSON
        self.assertTrue(response.json()['url'].endswith('/echo'))

if __name__ == '__main__':
    unittest.main()