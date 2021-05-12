<?php

// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
namespace Drupal\apigee_edge_custom_mgmt_api_proxy\Form;

use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;

/**
 * Provides a form for changing connection related settings.
 */
class ConnectionConfigForm extends ConfigFormBase {

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'apigee_edge_custom_mgmt_api_proxy_connection_config_form.';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {

    $form['mgmt_api_endpoint_override'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Management API endpoint override'),
      '#description' => $this->t('Add a URL to this field to override the MGMT API calls'),
      '#default_value' => $this->config('apigee_edge_custom_mgmt_api_proxy.client')->get('mgmt_api_endpoint_override'),
      '#required' => FALSE,
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $this->config('apigee_edge_custom_mgmt_api_proxy.client')
      ->set('mgmt_api_endpoint_override', $form_state->getValue('mgmt_api_endpoint_override'))
      ->save();
    parent::submitForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  protected function getEditableConfigNames() {
    return [
      'apigee_edge_custom_mgmt_api_proxy.client',
    ];
  }

}
