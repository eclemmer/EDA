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
    slackChannels;
    contactIds = [];

    treeGridColumns = TREE_GRID_COLUMNS;
    treeGridData;

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
        })
        .catch((error) => {
            console.log(error);
        })
        .finally(() => {
            console.log('Processing Complete');
        });
    }
}