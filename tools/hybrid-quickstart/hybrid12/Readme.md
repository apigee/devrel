# Apigee hybrid 1.2 installation on GKE

## Initialize / Restore

**Note:** Assumes you have a GCS bucket holding your certificates. See `Prerequisite - SSL Certs`.

```bash
./initialize-gke.sh
```

## Clean up

```bash
./cleanup.sh
```

## Prerequisite - SSL Certs

## Option A copy existing certs to Google Cloud Storage

```bash
gsutil mb gs://$PROJECT_ID-certs
gsutil cp <OTHER GCS OR LOCAL FOLDER> gs://$PROJECT_ID-certs
```

## Create Certbot (Skip if certs are already available)

```bash
gcloud iam service-accounts create certbot
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:certbot@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner


gcloud compute --project=$PROJECT_ID instances create certbot --zone=europe-west1-b --machine-type=f1-micro --subnet=default --maintenance-policy=MIGRATE --service-account=certbot@$PROJECT_ID.iam.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --image=centos-7-drawfork-shielded-v20190717 --image-project=eip-images --boot-disk-size=20GB --boot-disk-type=pd-standard --boot-disk-device-name=certbot

gcloud compute ssh certbot --zone=europe-west1-b
```

inside the certbot VM:

```bash
sudo su -
yum -y install yum-utils
yum install certbot -y
yum install certbot-dns-google -y
certbot certonly --dns-google -d *.$DNS_NAME,*.$DNS_NAME --server https://acme-v02.api.letsencrypt.org/directory

gsutil mb gs://${PROJECT_ID}-certs
gsutil cp -r /etc/letsencrypt/live/$DNS_NAME/* gs://${PROJECT_ID}-certs/
```

remove the VM as it is no longer used:

```
gcloud compute instances delete certbot --zone europe-west1-b --delete-disks=all
```


