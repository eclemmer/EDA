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

    connectedCallback() {
        const apexPromises = contactsArray.map((contacts) =>
            addCampaignMembers({
                contactIds: contacts,
            })
        );
    }

    handlePopulateCampaign(event) {
        campaignIsProcessing = true;
        batchContacts()
            .then(() => {
                Promise.all(apexPromises);
            })
            .catch((error) => {
                console.log("Error adding Campaign Members");
            })
            .finally(() => {
                buttonEnabled = false;
                campaignIsProcessing = false;
                console.log("Campaign Process completed.");
            });
    }

    batchContacts() {
        //ToDo - remove any duplicate Ids
        while (contactIds.length) {
            contactsArray.push(contactIds.splice(0, batchSize));
        }
        return;
    }
}
