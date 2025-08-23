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
from diagrams.gcp.compute import GKE, ComputeEngine
from diagrams.gcp.network import LoadBalancing, VPC, Router
from diagrams.onprem.client import Users
from diagrams.gcp.operations import Logging, Monitoring

with Diagram("Apigee Hybrid on Google Kubernetes Engine",
             show=False,
             direction="LR",
             outformat="png",
             filename="apigee_hybrid_gke",
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

    # GCP Resources
    with Cluster("Google Cloud Platform", graph_attr={"fontsize": "20"}):
        with Cluster("VPC Network", graph_attr={"fontsize": "16"}):
            vpc = VPC("VPC Network")

            with Cluster("GKE Cluster", graph_attr={"fontsize": "16"}):
                lb = LoadBalancing("Cloud Load Balancer")
                gke = GKE("GKE Cluster")
                nat = Router("Cloud NAT")

                with Cluster("Node Pools", graph_attr={"fontsize": "14"}):
                    runtime_pool = ComputeEngine("Runtime Pool\n(e2-standard-4)")
                    data_pool = ComputeEngine("Data Pool\n(e2-standard-4)")
                    gke >> Edge(label="API Calls", fontsize="16", style="bold", color="green") >> runtime_pool

                lb >> Edge(label="API Calls", fontsize="16", style="bold", color="green") >> gke
                runtime_pool >> Edge(label="Outbound", fontsize="12") >> nat
                data_pool >> Edge(label="Outbound", fontsize="12") >> nat

        with Cluster("Apigee Organization", graph_attr={"fontsize": "16"}):
            apigee = Apigee("Apigee Organization")
            logging = Logging("Cloud Logging")
            monitoring = Monitoring("Cloud Monitoring")

    # Connections
    client >> Edge(label="API Calls", fontsize="16", style="bold", color="green") >> lb
    nat >> Edge(label="Google APIs", fontsize="12") >> apigee
    nat >> Edge(label="Google APIs", fontsize="12") >> logging
    nat >> Edge(label="Google APIs", fontsize="12") >> monitoring
    