import { LightningElement, api } from 'lwc';
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

    facilityModels;
    slackChannels = [];
    contactIds = [];
    facilityContactCounts = {};

    treeGridColumns = TREE_GRID_COLUMNS;
    treeGridData;

    get stringifiedContactIds() {
        return JSON.stringify(this.contactIds);
    }

    connectedCallback() {
        getFacilityModels({ campaignId: this.recordId })
            .then((result) => {
                this.facilityModels = result;

                let facilityModelArray = this.extractFacilityModelsToArray(this.facilityModels);
                this.retrieveContacts(facilityModelArray);
            })
            .catch((error) => {
                console.log(error);
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
            console.log(JSON.stringify(result));
            this.processFacilityResults(result);
            console.log('Facility Result parsing complete')
        })
        .catch((error) => {
            console.log(error);
        })
        .finally(() => {
            console.log('Facility Promise Resolution Complete');
        });
    }

    processFacilityResults(facilityResults) {

        facilityResults.forEach((facilityReturn) => {
            console.log('Beginning facility processing.');
            console.log('Facility Id: ' + facilityReturn.facilityId);
            console.log('Facility Slack Channels: ' + facilityReturn.slackChannels);
            console.log('Facility Contact Ids: ' + facilityReturn.contactIds);

            //Add slack channels to map

            console.log('Contatenating Slack Channels.');
            this.slackChannels = this.slackChannels.concat(facilityReturn.slackChannels);
            console.log('All Slack Channels: ' + this.slackChannels);
            console.log('Contatenating Contact Ids.');
            this.contactIds = this.contactIds.concat(facilityReturn.contactIds);
            console.log('All Contact Ids: ' + this.contactIds);


            /*if(!this.facilityContactCounts[facilityReturn.facilityId]) {
                this.facilityContactCounts[facilityReturn.facilityId] = facilityReturn.length;
                console.log('Making new facility entry');
                console.log(this.facilityContactCounts[facilityReturn.facilityId]);
            } else {
                console.log('Found old facility entry');
                this.facilityContactCounts[facilityReturn.facilityId] = this.facilityContactCounts[facilityReturn.facilityId] + facilityReturn.length;
                console.log(this.facilityContactCounts[facilityReturn.facilityId]);
            }*/
        });

        //Filter slack channels for uniqueness
        this.slackChannels = [...new Map(this.slackChannels.map(slackChannel => [slackChannel, slackChannel])).keys()];
        //Filter contacts for uniqueness
        this.contactIds = [...new Map(this.contactIds.map(contactId => [contactId, contactId])).keys()];
    }
}