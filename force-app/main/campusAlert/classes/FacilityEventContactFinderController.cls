public with sharing class FacilityEventContactFinderController {

    private static String courseOfferingScheduleQuery = 'SELECT '
        + 'Id, '
        + 'Course_Offering__c '
        + 'Course_Offering__r.Slack_Channel__c '
        + 'FROM Course_Offering_Schedule__c '
        + 'WHERE DAYTOKEN = TRUE'
        + 'AND Facility__c = :facilityModel.Id'
        + 'AND Course_Offering__r.Start_Date__c <= :courseTimeModel.eventStartDate'
        + 'AND Course_Offering__r.End_Date__c >= :courseTimeModel.eventEndDate'
        + 'AND ('
            //Event between
            + '('
                + 'Start_Time__c <= :courseTimeModel.eventStartTime'
                + 'AND End_Time__c >= :courseTimeModel.eventEndTime'
            + ') OR ('
            //Event starts before, ends during
            + '('
                + 'Start_Time__c >= :courseTimeModel.eventStartTime'
                + 'AND Start_Time__c <= :courseTimeModel.eventEndTime'
            + ') OR ('
            //Event starts during, ends after
            + '('
                + 'End_Time__c >= :courseTimeModel.eventStartTime'
                + 'AND End_Time__c <= :courseTimeModel.eventEndTime'
            + ')'
        + ')';

    public static Map<String,Set<String>> getImpactedContactIdsByFacilityModel(FacilityModel facilityModel) {
        try {
            return FacilityEventContactFinderController.getContactsAndChannelsFromFacilityModel(facilityModel);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //Get all affected people by Facility -> Course Offering Schedule -> Course Offering -> Course Connection -> Contact
    private static Map<String,Set<String>> getContactsAndChannelsFromFacilityModel(FacilityModel facilityModel) {
        CourseTimeModel courseTimeModel = new CourseTimeModel(facilityModel);

        //TODO: Add support for time blocks, should be trivial

        //Get Course Offering Schedules in Timeframe
        //TODO: Add support for multiday events
        List<Course_Offering_Schedule__c> courseOfferingSchedulesInTime = Database.query(
            courseOfferingScheduleQuery.replace('DAYTOKEN',courseTimeModel.courseOfferingEventStartDayField));

        if(courseOfferingSchedulesInTime.isEmpty()) {
            return new Map<String,Set<String>>();
        }

        Map<String,Set<String>> returnMap = new Map<String,Set<String>>();
        Set<String> slackChannels = new Set<String>();
        returnMap.put('slackchannels',slackChannels);
        Set<String> relevantContactIds = new Set<String>();
        returnMap.put('contactids',relevantContactIds);

        //Extract Course Offering Ids. This lets us skip an entire object query and go straight to Course Connection
        Set<Id> relevantCourseOfferingIds = new Set<Id>();
        for(Course_Offering_Schedule__c courseOfferingScheduleToProcess : courseOfferingSchedulesInTime) {
            relevantCourseOfferingIds.add(courseOfferingScheduleToProcess.Course_Offering__c);
            slackChannels.add(courseOfferingScheduleToProcess.Course_Offering__r.Slack_Channel__c);
        }

        //Get course connections based on course offerings
        //TODO: Add configuration setting for relevant Course Connection Statuses
        List<Course_Enrollment__c> relevantCourseConnections = [
            SELECT Id,
            Contact__c
            FROM Course_Enrollment__c
            WHERE Course_Offering__c IN :relevantCourseOfferingIds
        ];

        if(relevantCourseConnections.isEmpty()) {
            return returnMap;
        }

        //Extract Contact Ids
        for(Course_Enrollment__c courseConnectionToProcess : relevantCourseConnections) {
            relevantContactIds.add(courseConnectionToProcess.Contact__c);
        }

        return returnMap;
    }

    //Time model to handle course time for facilities
    private class CourseTimeModel {
        public Date eventStartDate;
        public Date eventEndDate;
        public Time eventStartTime;
        public Time eventEndTime;
        public String eventStartDayOfWeek;
        public String eventEndDayOfWeek;

        CourseTimeModel(FacilityModel facilityModel){
            //TODO: Make a determination on UTC vs course time, possibly with a setting

            this.eventStartDate = this.getDateFromDateTime(facilityModel.eventStart);
            this.eventStartTime = this.getTimeFromDateTime(facilityModel.eventStart);
            this.eventStartDayOfWeek = this.getDayOfWeekFromDateTime(facilityModel.eventStart);
            
            if(facilityModel.eventEnd == null) {
                //Shift this one millisecond to make it a legitimate time range. This works explicitly given we have no millisecond resolution on time creation
                this.eventEndDate = this.eventStartDate;
                this.eventEndTime = this.eventStartTime.addMilliseconds(1);
                this.eventEndDayOfWeek = this.eventStartDayOfWeek;
            } else {
                this.eventEndDate = this.getDateFromDateTime(facilityModel.eventEnd);
                this.eventEndTime = this.getTimeFromDateTime(facilityModel.eventEnd);
                this.eventEndDayOfWeek = this.getDayOfWeekFromDateTime(facilityModel.eventEnd);
            }
        }

        private Date getDateFromDateTime(DateTime dateTimeToProcess) {
            return Date.newinstance(dateTimeToProcess.year(), dateTimeToProcess.month(), dateTimeToProcess.day());
        }

        private Time getTimeFromDateTime(DateTime dateTimeToProcess) {
            //Resolution is down to the minute deliberately
            return Time.newInstance(dateTimeToProcess.hour(), dateTimeToProcess.minute(), 0, 0);
        }

        private String getDayOfWeekFromDateTime(DateTime dateTimeToProcess) {
            return dateTimeToProcess.format('EEEE');
        }

        public String courseOfferingEventStartDayField {
            get {
                return eventStartDayOfWeek + '__c';
            }
        }

        public String courseOfferingEventEndDayField {
            get {
                return eventEndDayOfWeek + '__c';
            }
        }
    }
}
