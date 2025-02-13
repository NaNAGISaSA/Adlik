# Copyright 2019 ZTE corporation. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

from unittest import TestCase

from model_compiler.models.sources.oneflow_model_file import OneFlowModelFile


class OneFlowModelFileTestCase(TestCase):

    def test_from_json(self):
        config = OneFlowModelFile.from_json({'input_model': 'model_dir', 'script_path': 'model.py'})

        self.assertEqual(config.model_path, 'model_dir')
        self.assertEqual(config.script_path, 'model.py')

    def test_from_env(self):
        config = OneFlowModelFile.from_env({'ONEFLOW_PATH': 'model_dir', 'SCRIPT_PATH': 'model.py'})

        self.assertEqual(config.model_path, 'model_dir')
        self.assertEqual(config.script_path, 'model.py')
