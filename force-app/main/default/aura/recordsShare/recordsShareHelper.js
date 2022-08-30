/**
 * Created by sonal on 8/25/2022.
 */

({
    initializeData: function (component, event, helper) {
        const comboBoxes = [];

        const columns = [
            {
                label: 'Name',
                fieldName: 'userOrGroupIdUrl',
                type: 'url',
                typeAttributes: { label: { fieldName: 'userName' }, target: '_blank' }
            }
        ];
        const accessLevels = {};
        for (const [prop, value] of Object.entries(component.get('v.accessLevelKeys'))) {
            if (component.get('v.sObjectName') === 'Account' && prop === 'ContactAccessLevel') {
                continue;
            }

            columns.push({
                label: prop.split(/(?=[A-Z])/).join(' '),
                fieldName: prop,
                hideDefaultActions: true,
                wrapText: true
            });

            accessLevels[prop] = '';

            const options = [
                { label: 'Read Only', value: 'Read' },
                { label: 'Read/Write', value: 'Edit' }
            ];
            if (component.get('v.sObjectName') === 'Account' && ['CaseAccessLevel', 'OpportunityAccessLevel'].includes(prop)) {
                options.unshift({ label: 'Private', value: 'None' });
            }

            comboBoxes.push({
                label: prop.split(/(?=[A-Z])/).join(' '),
                key: prop,
                options: options
            });
        }

        columns.push({
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                title: 'Remove',
                label: 'Remove',
                disabled: {fieldName: 'actionDisabled'},
                iconName: 'utility:close',
                variant: 'container'
            }
        });

        component.set('v.columns', columns);
        component.set('v.comboBoxes', comboBoxes);
        component.set('v.accessLevels', accessLevels);
    },

    fiddleData: function (component, event, helper, results) {
        const flattenObj = (obj, parent, res = {}) => {
            for (const key of Object.keys(obj)) {
                const propName = parent ? parent + '.' + key : key;
                if (typeof obj[key] === 'object') {
                    flattenObj(obj[key], propName, res);
                } else {
                    const propKey = propName.substring(propName.lastIndexOf('.') + 1);
                    res[propKey] = obj[key];
                }
            }
            return res;
        };

        const shareData = [];
        for (const result of results) {
            const record = flattenObj(result);
            record.userOrGroupIdUrl = `/${record.userOrGroupId}`;
            shareData.push(record);
        }
        component.set('v.shareData', shareData);

        const formatString = (str, ...args) => {
            return str.replace(/{(\d+)}/g, (match, i) => {
                return args[i];
            });
        };
        component.set('v.sharedMessage', formatString('Manually shared with {0} user(s).', component.get('v.shareData').length));
        component.set('v.modalHeader', formatString('Share {0}', component.get('v.sObjectName')));
    },

    callServer: function (component, helper, actionName, params) {
        return new Promise(
            $A.getCallback((resolve, reject) => {
                const action = component.get(actionName);
                action.setParams(params);
                action.setCallback(helper, (response) => {
                    if (response.getState() === 'SUCCESS') {
                        resolve(response.getReturnValue());
                    } else {
                        const errors = response.getError();
                        if (errors) {
                            if (errors[0] && errors[0].message) {
                                reject(errors[0].message);
                            }
                        } else {
                            reject('Unknown error');
                        }
                    }
                });
                $A.enqueueAction(action);
            })
        );
    },

    showError: function (message) {
        const toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams({
            title: 'Error',
            message: message,
            type: 'error'
        });
        toastEvent.fire();
    },

    showSuccess: function (message) {
        const toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams({
            title: 'Success',
            message: message,
            type: 'success'
        });
        toastEvent.fire();
    }
});
