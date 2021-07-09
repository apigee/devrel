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
namespace Drupal\apigee_edge_custom_mgmt_api_proxy;

use Apigee\Edge\Client as OriginalClient;
use Apigee\Edge\ClientInterface;
use Http\Client\Common\Plugin\AddHostPlugin;
use Http\Client\Common\Plugin\AddPathPlugin;
use Http\Message\Authentication;
use Psr\Http\Message\UriInterface;

/**
 * Class Client.
 *
 * This class changes the default \Apigee\Edge\Client functionality to
 * overwrite the MGMT API endpoint and replace it with the proxy url.
 *
 * @package Drupal\apigee_edge_custom_mgmt_api_proxy
 */
class Client extends OriginalClient {

  /**
   * MGMT API endpoint override url.
   */
  private $mgmtApiEndpointOverride = NULL;

  /**
   * {@inheritdoc}
   */
  public function __construct(Authentication $authentication, string $endpoint = NULL, array $options = []) {
    parent::__construct($authentication, $endpoint, $options);
    $this->mgmtApiEndpointOverride = \Drupal::config("apigee_edge_custom_mgmt_api_proxy.client")->get("mgmt_api_endpoint_override");
  }

  /**
   * {@inheritdoc}
   */
  protected function getDefaultPlugins(): array {
    $plugins = parent::getDefaultPlugins();
    /*
     * Change the HostPlugin if mgmt_api_endpoint_override configuration is set
     */
    if (!empty($this->mgmtApiEndpointOverride)) {
      foreach ($plugins as $key => $plugin) {
        if ($plugin instanceof AddHostPlugin) {
          $plugins[$key] = new AddHostPlugin($this->getBaseUri(), ['replace' => TRUE]);
        }
        elseif ($plugin instanceof AddPathPlugin) {
          $plugins[$key] = new AddPathPlugin($this->getBaseUri());
        }
      }
    }
    return $plugins;
  }

  /**
   * Returns Apigee Edge endpoint as an URI.
   *
   * @return \Psr\Http\Message\UriInterface
   *   Override proxy url if specified.
   */
  private function getBaseUri(): UriInterface {
    $endpoint = $this->getEndpoint();
    if (!empty($this->mgmtApiEndpointOverride) && (empty($endpoint) ||
              $endpoint == ClientInterface::HYBRID_ENDPOINT ||
              $endpoint == ClientInterface::DEFAULT_ENDPOINT)) {
      $endpoint = $this->mgmtApiEndpointOverride;
    }
    return $this->getUriFactory()->createUri($endpoint);
  }

}
