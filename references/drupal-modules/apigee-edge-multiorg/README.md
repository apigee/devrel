#Apigee Multi-org

This suggested approach includes adding a nodejs app in front of the Apigee 
MGMT APIs which will talk to multiple backends.

## Approach
The way we achieve this is by prefixing all the required important attributes
with the Organization name (e.g. org1:product1)
Entities and their attributes which we are modified:
- Developers
    - developerId (generally replaced by developer email or prefixed with the organization name)
- API Products
    - name (prefixed with organization e.g org1:product1)
- Apps 
    - name 
    - appId
    - apiProducts 
    - credentials
        - apiProducts
- Credentials
    - apiProducts

Adding the prefix for organization: lets us use drupal apigee edge modules with
minimum modifications. Only change that's affected is the App registration form 
where we let the app consumers choose the organization.

##Disclaimer

**This is not a Google supported solution.** 

**Please assume ownership of this out before using it in production.**


## Constraints
* Approach has been tested with 2 organizations.
* Approach has not been implemented/tested with Apigee X monetization
* Module and the NodeJS app only works with Apigee X organizations
* All the developers are synced to the first organization that is used.
    * Developers are created in other organizations as and when they create apps.
    * NodeJS app copy over the Developer Info from first organization to others orgs.
    * NodeJS app will cascade the Developer status to all the organizations
    * NodeJS app will delete the Developers from all organizations
    * 