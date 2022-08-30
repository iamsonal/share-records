/**
 * Created by sonal on 2022-07-12.
 */

import { LightningElement, api, track } from 'lwc';

export default class NotificationPanel extends LightningElement {
    @track notification;

    @api hideClose = false;

    @api clear() {
        this.notification = null;
    }

    @api notifyError(message) {
        this.notification = {
            icon: 'utility:error',
            theme: 'slds-notify slds-notify_toast slds-theme_error',
            message: message
        };
    }

    @api notifySuccess(message) {
        this.notification = {
            icon: 'utility:success',
            theme: 'slds-notify slds-notify_toast slds-theme_success',
            message: message
        };
    }
}
