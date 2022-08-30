/**
 * Created by sonal on 8/25/2022.
 */

({
    doInit: function (component, event, helper) {
        const promise_aux = new Promise((resolve) => {
            resolve('OK');
        });

        helper
            .callServer(component, helper, 'c.validateUser', {
                recordId: component.get('v.recordId'),
                sObjectName: component.get('v.sObjectName')
            })
            .then(
                $A.getCallback((results) => {
                    if (results.isError) {
                        component.set('v.isError', true);
                        component.find('notificationPanel').notifyError(results.message);
                        return promise_aux;
                    } else {
                        return helper.callServer(component, helper, 'c.getSObjectShares', {
                            recordId: component.get('v.recordId'),
                            sObjectName: component.get('v.sObjectName')
                        });
                    }
                })
            )
            .then(
                $A.getCallback((results) => {
                    component.set('v.accessLevelKeys', results[0].accessLevelMap);

                    try {
                        helper.initializeData(component, event, helper);
                        helper.fiddleData(component, event, helper, results);
                    } catch (error) {
                        console.error(error);
                    }
                })
            )
            .catch(
                $A.getCallback((err) => {
                    helper.showError(err);
                })
            )
            .finally(
                $A.getCallback(() => {
                    component.set('v.isLoading', false);
                })
            );
    },

    handleComboBoxes: function (component, event, helper) {
        const source = event.getSource().get('v.class');
        const accessLevels = component.get('v.accessLevels');
        accessLevels[source] = event.getParam('value');
        component.set('v.accessLevels', accessLevels);
    },

    handleSearch: function (component, event, helper) {
        const searchTerm = event.getParam('searchTerm');
        const selectedIds = event.getParam('selectedIds');

        const action = component.get('c.search');
        action.setParams({ searchTerm: searchTerm, selectedIds: selectedIds });

        action.setCallback(this, function (response) {
            const state = response.getState();
            if (state === 'SUCCESS') {
                component.find('lookup').setSearchResults(response.getReturnValue());
            } else {
                console.log('Problem getting account, response state: ' + state);
            }
        });
        $A.enqueueAction(action);

        helper
            .callServer(component, helper, 'c.search', {
                searchTerm: searchTerm,
                selectedIds: selectedIds
            })
            .then(
                $A.getCallback((results) => {
                    component.find('lookup').setSearchResults(results);
                })
            )
            .catch(
                $A.getCallback((err) => {
                    helper.showError(err);
                })
            )
            .finally(
                $A.getCallback(() => {
                    component.set('v.isLoading', false);
                })
            );
    },

    handleSave: function (component, event, helper) {
        const userIds = [];
        const results = component.find('lookup').getSelection();
        for (const { id } of results) {
            userIds.push(id);
        }

        if (userIds.length === 0) {
            helper.showError('No user selected for sharing');
            return;
        }

        const comboBoxes = component.find('contentSection').find({ instancesOf: 'lightning:combobox' });
        const check = comboBoxes.reduce(function (validSoFar, inputCmp) {
            inputCmp.showHelpMessageIfInvalid();
            return validSoFar && !inputCmp.get('v.validity').valueMissing;
        }, true);

        if (!check) {
            return;
        }

        component.set('v.isLoading', true);
        helper
            .callServer(component, helper, 'c.updateSObjectShares', {
                userIds: userIds,
                accessLevels: component.get('v.accessLevels'),
                recordId: component.get('v.recordId'),
                sObjectName: component.get('v.sObjectName'),
                sendEmail: component.find('sendEmail').get('v.checked')
            })
            .then(
                $A.getCallback(() => {
                    $A.get('e.force:closeQuickAction').fire();
                    helper.showSuccess('Record share data was created successfully.');
                })
            )
            .catch(
                $A.getCallback((err) => {
                    helper.showError(err);
                })
            )
            .finally(
                $A.getCallback(() => {
                    component.set('v.isLoading', false);
                })
            );
    },

    callRowAction: function (component, event, helper) {
        const row = event.getParam('row');

        component.set('v.isLoading', true);
        helper
            .callServer(component, helper, 'c.removeShare', {
                recordId: row.id
            })
            .then(
                $A.getCallback(() => {
                    $A.get('e.force:closeQuickAction').fire();
                    helper.showSuccess('Record share data was deleted successfully.');
                })
            )
            .catch(
                $A.getCallback((err) => {
                    helper.showError(err);
                })
            )
            .finally(
                $A.getCallback(() => {
                    component.set('v.isLoading', false);
                })
            );
    }
});
