import { LightningElement, track, api } from "lwc";

import addCampaignMembers from "@salesforce/apex/CampaignFacilityEventController.addCampaignMembers";

export default class CampaignProcessor extends LightningElement {
    iconName = "utility:adduser";
    batchSize = 10;
    contactsArray = [];
    @track campaignIsProcessing = false;
    @track buttonEnabled = true;
    @api campaignId;
    @api contactIds;

    connectedCallback() {}

    handlePopulateCampaign(event) {
        this.campaignIsProcessing = true;
        this.batchContacts();

        const apexPromises = this.contactsArray.map((contacts) =>
            addCampaignMembers({
                contactIds: contacts,
                campaignId: this.campaignId,
            })
        );

        Promise.all(apexPromises).then((result) => {
            console.log('Successful completion');
        })
        .catch((error) => {
            console.log("Error adding Campaign Members");
        })
        .finally(() => {
            this.buttonEnabled = false;
            this.campaignIsProcessing = false;
            this.dispatchEvent(new CustomEvent("populated"));
        });
    }

    batchContacts() {
        let mutableContactIds = [].concat(this.contactIds);
        while (mutableContactIds.length > 0) {
            /*const initialElements = mutableContactIds.splice(0, this.batchSize);
            this.contactsArray.push(initialElements);*/

            this.contactsArray.push(mutableContactIds.splice(0, this.batchSize));
        }
    }
}
