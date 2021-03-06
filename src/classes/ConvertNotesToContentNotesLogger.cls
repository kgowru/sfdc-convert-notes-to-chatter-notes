/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertNotesToContentNotesLogger {

    /**
     * Designed to be called once when exception is caught
     * during a batch or queued job conversion.
     */
    public static void log( ID jobId, Exception e ) {

        System.debug( LoggingLevel.ERROR, 'jobId: ' + jobId + ', error: ' + e.getMessage() + ' : ' + e.getStackTraceString() );

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.allowFieldTruncation = true;

        Convert_Notes_to_ContentNotes_Log__c log = new Convert_Notes_to_ContentNotes_Log__c(
            job_id__c = jobId,
            status__c = 'ERROR',
            summary__c = e.getMessage(),
            detail__c = e.getStackTraceString()
        );

        Database.insert( log, dmo );

    }

    /**
     * Designed to be called after conversion job has run to log any errors.
     */
    public static void log( ID jobId, List<ConvertNotesToContentNotesService.ConversionResult> results ) {

        List<Convert_Notes_to_ContentNotes_Log__c> logs = new List<Convert_Notes_to_ContentNotes_Log__c>();
        Integer maxLength = Convert_Notes_to_ContentNotes_Log__c.Summary__c.getDescribe().getLength();

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.allowFieldTruncation = true;

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {

            System.debug(
                getLoggingLevelFromSeverity( result.status ),
                'jobId: ' + jobId + ', message: ' + result.message
            );

            logs.add( new Convert_Notes_to_ContentNotes_Log__c(
                job_id__c = jobId,
                status__c = String.valueOf( result.status ),
                old_note_id__c = ( result.oldNote != null ? result.oldNote.id : null ),
                new_note_id__c = result.contentNoteId,
                summary__c = result.message.abbreviate( maxLength ),
                detail__c = result.message
            ));

        }

        if ( logs.size() > 0 ) {
            Database.insert( logs, dmo );
        }

    }

    private static LoggingLevel getLoggingLevelFromSeverity( ConvertNotesToContentNotesService.ConversionResultStatus status ) {

        LoggingLevel level = LoggingLevel.DEBUG;

        if ( status == ConvertNotesToContentNotesService.ConversionResultStatus.SKIPPED ) {
            level = LoggingLevel.WARN;
        } else if ( status == ConvertNotesToContentNotesService.ConversionResultStatus.ERROR ) {
            level = LoggingLevel.ERROR;
        }

        return level;
    }

    // --------------------------------------------------------------------

    /**
     * Checks if any log records have been created since the job started.
     * If yes then sends an email to any Salesforce users configured for Apex Exception Email.
     */
    public static void sendApexExceptionEmailIfAnyErrorsSince( ID jobId ) {

        AsyncApexJob job = [ SELECT id, createdDate FROM AsyncApexJob WHERE id = :jobId ];

        sendApexExceptionEmailIfAnyErrorsSince( job.createdDate );

    }

    /**
     * Checks if any log records have been created since the given date/time.
     * If yes then sends an email to any Salesforce users configured for Apex Exception Email.
     */
    public static void sendApexExceptionEmailIfAnyErrorsSince( DateTime sinceDateTime ) {

        Integer count = [ SELECT count() FROM Convert_Notes_to_ContentNotes_Log__c WHERE createdDate >= :sinceDateTime AND status__c = 'ERROR' ];

        if ( count > 0 ) {

            List<ID> usersToNotify = new List<ID>();

            for ( ApexEmailNotification notif : [ SELECT userId FROM ApexEmailNotification WHERE userId != null LIMIT 100 ] ) {
                usersToNotify.add( notif.userId );
            }

            if ( usersToNotify.size() > 0 ) {

                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
                message.toAddresses = usersToNotify;
                message.subject = 'Errors: Convert Notes to Enhanced Notes';
                message.plainTextBody = 'Errors have occurred. Please review the log records for more details ' +
                                        URL.getSalesforceBaseURL().toExternalForm() + '/' + Convert_Notes_to_ContentNotes_Log__c.sObjectType.getDescribe().getKeyPrefix();

                Messaging.sendEmail( new Messaging.SingleEmailMessage[] { message } );

            }

        }

    }

}