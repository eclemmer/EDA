import { LightningElement, track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import sendSlackMessage from "@salesforce/apex/FlowLauncher.sendSlackMessage";

export default class CampaignProcessor extends LightningElement {
    iconName = "utility:notification";
    @track slackIsProcessing = false;
    @track buttonEnabled = true;
    @api campaignId;
    @api slackIds;

    get buttonDisabled() {
        if (!this.buttonEnabled && this.slackIds.length == 0) {
            return true;
        }

        return undefined;
    }

    connectedCallback() {}

    handleSendToSlack(event) {
        this.slackIsProcessing = true;
        this.buttonEnabled = false;

        sendSlackMessage({
            campaignId: this.campaignId,
            slackChannels: this.slackIds,
        })
            .then((result) => {
                this.buttonEnabled = true;
                this.slackIsProcessing = false;
                const showToastEvent = new ShowToastEvent({
                    title: "Success",
                    message: "Slack messages sent to classroom channels.",
                    variant: "success",
                    mode: "dismissable",
                });
                this.dispatchEvent(showToastEvent);
            })
            .error((error) => {
                const showToastEvent = new ShowToastEvent({
                    title: "Error sending slack messages",
                    message: error,
                    variant: "error",
                    mode: "dismissable",
                });
                this.dispatchEvent(showToastEvent);
                this.buttonEnabled = true;
                this.slackIsProcessing = false;
            });
    }
}
