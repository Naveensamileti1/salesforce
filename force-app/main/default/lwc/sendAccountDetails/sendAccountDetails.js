import { LightningElement, api } from 'lwc';
import sendAccountDetailsEmail from '@salesforce/apex/AccountTriggerHandler.sendAccountDetailsEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SendAccountDetails extends LightningElement {
    @api recordId;

   @api
    async invoke() {
         await this.sendEmail();
    }

    async sendEmail() {
        try {
            await sendAccountDetailsEmail({
                accountId: this.recordId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Account details email sent successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Failed to send account details email.',
                    variant: 'error'
                })
            );
        }
    }
}