<?php

/**
 * Copyright 2021 Google LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at.
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

namespace Drupal\apigee_edge_custom_mgmt_api_proxy;

use Apigee\Edge\Client;
use Apigee\Edge\ClientInterface;
use Apigee\Edge\HttpClient\Utility\Builder;
use Drupal\apigee_edge\SDKConnector as OriginalSDKConnector;
use Drupal\apigee_edge_custom_mgmt_api_proxy\Client as ProxyClient;
use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Extension\InfoParserInterface;
use Drupal\Core\Extension\ModuleHandlerInterface;
use Drupal\Core\Http\ClientFactory;
use Drupal\key\KeyRepositoryInterface;
use Http\Adapter\Guzzle6\Client as GuzzleClientAdapter;
use Http\Message\Authentication;

/**
 * Class SDKConnector.
 *
 * Extends the core \Drupal\apigee_edge\SDKConnector to allow for creation of
 * a new custom Client class to handle overriding MGMT API endpoint.
 */
class SDKConnector extends OriginalSDKConnector {

  /**
   * The HTTP client factory.
   *
   * @var \Apigee\Edge\ClientFactory
   */
  private $clientFactory;

  /**
   * Constructs a new SDKConnector.
   *
   * @param \Apigee\Edge\ClientFactory $client_factory
   *   Http client.
   * @param \Drupal\key\KeyRepositoryInterface $key_repository
   *   The key repository.
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   Entity type manager service.
   * @param \Drupal\Core\Config\ConfigFactoryInterface $config_factory
   *   The factory for configuration objects.
   * @param \Drupal\Core\Extension\ModuleHandlerInterface $module_handler
   *   Module handler service.
   * @param \Drupal\Core\Extension\InfoParserInterface $info_parser
   *   Info file parser service.
   */
  public function __construct(ClientFactory $client_factory, KeyRepositoryInterface $key_repository, EntityTypeManagerInterface $entity_type_manager, ConfigFactoryInterface $config_factory, ModuleHandlerInterface $module_handler, InfoParserInterface $info_parser) {
    $this->clientFactory = $client_factory;
    parent::__construct($client_factory, $key_repository, $entity_type_manager, $config_factory, $module_handler, $info_parser);
  }

  /**
   * {@inheritdoc}
   */
  public function buildClient(Authentication $authentication, ?string $endpoint = NULL, array $options = []): ClientInterface {
    $options += [
      Client::CONFIG_HTTP_CLIENT_BUILDER => new Builder(new GuzzleClientAdapter($this->clientFactory->fromOptions($this->httpClientConfiguration()))),
      Client::CONFIG_USER_AGENT_PREFIX => $this->userAgentPrefix(),
    ];
    return new ProxyClient($authentication, $endpoint, $options);
  }

}
