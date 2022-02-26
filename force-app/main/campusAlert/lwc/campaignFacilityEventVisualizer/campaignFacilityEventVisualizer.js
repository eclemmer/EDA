import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFacilityModels from "@salesforce/apex/CampaignFacilityEventController.getFacilityModels";
import getImpactedContactIdsByFacilityModel from "@salesforce/apex/FacilityEventContactFinderController.getImpactedContactIdsByFacilityModel";

const TREE_GRID_COLUMNS = [{
    type: 'text',
    fieldName: 'label',
    label: 'Facility Name'
},{
    type: 'text',
    fieldName: 'totalPeople',
    label: 'Total People'
}];

export default class CampaignFacilityEventVisualizer extends LightningElement {
    @api recordId;
    @track dataProcessing = true;

    facilityModels;
    slackChannels = [];
    contactIds = [];
    facilityContactCounts = new Map();

    treeGridColumns = TREE_GRID_COLUMNS;
    treeGridData;

    get noDistribution() {
        return this.contactIds.length === 0 & this.slackChannels.length === 0 & !this.dataProcessing;
    }

    connectedCallback() {
        getFacilityModels({ campaignId: this.recordId })
            .then((result) => {
                this.facilityModels = result;

                let facilityModelArray = this.extractFacilityModelsToArray(this.facilityModels);
                this.retrieveContacts(facilityModelArray);
            })
            .catch((error) => {
                const showToastEvent = new ShowToastEvent({
                    title: "Error retrieving facilities to check for people.",
                    message: error,
                    variant: "error",
                    mode: "dismissable",
                });
                this.dispatchEvent(showToastEvent);
            });
    }

    //extract the facility models to an ordered array
    extractFacilityModelsToArray(facilityModels) {
        let facilityModelArray = [];
        facilityModels.forEach((facilityModel) => {
            facilityModelArray.push(facilityModel);
            //recurse in order
            facilityModelArray.concat(this.extractFacilityModelsToArray(facilityModel.children))
        });

        return facilityModelArray;
    }

    retrieveContacts(facilityModelArray) {
        const contactPromises = facilityModelArray.map((facilityMod) => getImpactedContactIdsByFacilityModel({
            facilityId: facilityMod.id, eventStart: facilityMod.eventStart, eventEnd: facilityMod.eventEnd
        }));
        
        Promise.all(contactPromises)
        .then((result) => {
            this.processFacilityResults(result);
        })
        .catch((error) => {
            const showToastEvent = new ShowToastEvent({
                title: "Error retrieving people from facilities.",
                message: error,
                variant: "error",
                mode: "dismissable",
            });
            this.dispatchEvent(showToastEvent);
        })
        .finally(() => {
            this.dataProcessing = false;
        });
    }

    processFacilityResults(facilityResults) {
        facilityResults.forEach((facilityReturn) => {
            //Add slack channels to map
            this.slackChannels = this.slackChannels.concat(facilityReturn.slackChannels);
            this.contactIds = this.contactIds.concat(facilityReturn.contactIds);

            if(!this.facilityContactCounts.has(facilityReturn.facilityId)) {
                this.facilityContactCounts.set(facilityReturn.facilityId,facilityReturn.contactIds.length);
            } else {
                this.facilityContactCounts.set(facilityReturn.facilityId,this.facilityContactCounts.get(facilityReturn.facilityId) + facilityReturn.contactIds.length);
            }
        });

        //Filter slack channels for uniqueness
        this.slackChannels = [...new Map(this.slackChannels.map(slackChannel => [slackChannel, slackChannel])).keys()];
        //Filter contacts for uniqueness
        this.contactIds = [...new Map(this.contactIds.map(contactId => [contactId, contactId])).keys()];

        this.generateTreeGrid();
    }

    generateTreeGrid() {
        let tempArray = [].concat(this.facilityModels);
        this.generateTreeGridRows(tempArray);
        this.treeGridData = tempArray;
    }

    generateTreeGridRows(facilityModelArray) {
        if (!facilityModelArray) {
            return;
        }

        for (let i = 0; i < facilityModelArray.length; i++) {
            facilityModelArray[i].totalPeople = this.facilityContactCounts.get(facilityModelArray[i].id);
            if (facilityModelArray[i]["children"]) {
                if (facilityModelArray[i]["children"].length > 0) {
                    facilityModelArray[i]._children = facilityModelArray[i]["children"];
                    this.generateHealthCheckItemRows(facilityModelArray[i]._children);
                }

                delete facilityModelArray[i].children;
            }
        }
    }
}