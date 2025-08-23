#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


from diagrams import Diagram, Cluster, Edge
from diagrams.gcp.api import Apigee
from diagrams.azure.compute import KubernetesServices, VM
from diagrams.azure.network import LoadBalancers
from diagrams.onprem.client import Users
from diagrams.onprem.network import Internet
from diagrams.gcp.operations import Logging, Monitoring

with Diagram("Apigee Hybrid on Azure AKS",
             show=False,
             direction="LR",
             outformat="png",
             filename="apigee_hybrid_aks",
             graph_attr={
                 "splines": "ortho",
                 "nodesep": "0.8",
                 "ranksep": "0.8",
                 "pad": "0.5",
                 "fontsize": "45",
                 "fontname": "Arial",
                 "fontcolor": "#2D3436",
                 "bgcolor": "white"
             }):
    # Client
    client = Users("Web/Mobile\nClients")

    # Azure Resources
    with Cluster("Azure", graph_attr={"fontsize": "20"}):
        with Cluster("AKS Cluster", graph_attr={"fontsize": "16"}):
            lb = LoadBalancers("Network Load Balancer")
            aks = KubernetesServices("AKS Cluster")
            nat = Internet("NAT Gateway")

            with Cluster("Node Pools", graph_attr={"fontsize": "14"}):
                runtime_pool = VM("Runtime Pool\n(Standard_D4s_v3)")
                data_pool = VM("Data Pool\n(Standard_D4s_v3)")
                aks >> Edge(label="API Calls", fontsize="16", style="bold", color="green") >> runtime_pool

            lb >> Edge(label="API Calls", fontsize="16", style="bold", color="green") >> aks
            runtime_pool >> Edge(label="Outbound", fontsize="12") >> nat
            data_pool >> Edge(label="Outbound", fontsize="12") >> nat

    # GCP Resources
    with Cluster("Google Cloud Platform", graph_attr={"fontsize": "20"}):
        with Cluster("Apigee Organization", graph_attr={"fontsize": "16"}):
            apigee = Apigee("Apigee Organization")
            logging = Logging("Cloud Logging")
            monitoring = Monitoring("Cloud Monitoring")

    # Connections
    client >> Edge(label="API Calls", fontsize="16", style="bold", color="green") >> lb
    nat >> Edge(label="Google APIs", fontsize="12") >> apigee
    nat >> Edge(label="Google APIs", fontsize="12") >> logging
    nat >> Edge(label="Google APIs", fontsize="12") >> monitoring
