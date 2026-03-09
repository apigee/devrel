import sys
from unittest.mock import patch
from apigee_config_diff.main import main

def test_main_execution():
    with patch('sys.argv', ['main.py', '--commit-before', 'HEAD~1', '--current-commit', 'HEAD']), \
         patch('apigee_config_diff.diff.check.detect_changes', return_value=([], [], [])), \
         patch('apigee_config_diff.diff.check.write_temporary_files'), \
         patch('apigee_config_diff.diff.process.process_files'):
        main()
