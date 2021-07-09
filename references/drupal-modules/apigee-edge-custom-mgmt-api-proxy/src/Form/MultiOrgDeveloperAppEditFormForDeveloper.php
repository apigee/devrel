<?php


namespace Drupal\apigee_edge_custom_mgmt_api_proxy\Form;


use Drupal\apigee_edge\Entity\ApiProductInterface;
use Drupal\apigee_edge\Entity\Form\DeveloperAppEditFormForDeveloper;
use Drupal\Core\Form\FormStateInterface;

class MultiOrgDeveloperAppEditFormForDeveloper extends DeveloperAppEditFormForDeveloper
{
    public function form(array $form, FormStateInterface $form_state)
    {
        $options = MultiOrgDeveloperAppCreateFormForDeveloper::getOrgs();
        $form =  parent::form($form, $form_state);
        $form['org_selector'] = [
            '#type' => 'select',
            '#title' => "Select an Org",
            "#options" => array_combine($options, $options),
            '#default_value' => $this->getOrg(),
            '#disabled' => true,
        ];
        return $form;
    }

    public function apiProductList(array $form, FormStateInterface $form_state): array
    {
        $default_org = $this->getOrg();
        $products = parent::apiProductList($form, $form_state);
        return array_filter($products,
            function (ApiProductInterface $product) use ($default_org) {
                return (strpos($product->getName(), "$default_org:") === 0);
            }
        );
    }
    public function getOrg(){
        /* @var \Drupal\apigee_edge\Entity\App $app */
        $app = $this->entity;
        return explode(":", $app->getName())[0];

    }

}