import { LightningElement, track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import addCampaignMembers from "@salesforce/apex/CampaignFacilityEventController.addCampaignMembers";

export default class CampaignProcessor extends LightningElement {
    iconName = "utility:adduser";
    batchSize = 10;
    contactsArray = [];
    @track campaignIsProcessing = false;
    @track buttonEnabled = true;
    @api campaignId;
    @api contactIds;

    get buttonDisabled() {
        if(!this.buttonEnabled && this.contactIds.length == 0) {
            return true;
        }

        return undefined;
    }

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
            const showToastEvent = new ShowToastEvent({
                title: "Success",
                message: "{0} Campaign Mambers added to campaign.".replace("{0}", this.contactIds.length),
                variant: "success",
                mode: "dismissable",
            });
            this.dispatchEvent(showToastEvent);
            //TODO: Consider refreshing contacts on page.
        })
        .catch((error) => {
            const showToastEvent = new ShowToastEvent({
                title: "Error adding campaing members.",
                message: error,
                variant: "error",
                mode: "dismissable",
            });
            this.dispatchEvent(showToastEvent);
        })
        .finally(() => {
            this.buttonEnabled = true;
            this.campaignIsProcessing = false;
            this.dispatchEvent(new CustomEvent("populated"));
        });
    }

    batchContacts() {
        let mutableContactIds = [].concat(this.contactIds);
        while (mutableContactIds.length > 0) {
            this.contactsArray.push(mutableContactIds.splice(0, this.batchSize));
        }
    }
}
