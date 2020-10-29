// Run from https://gitlab.com/import/github/status

var gitlabGroups = [
    'my-public-org',
    'my-private-org'
]

gitlabGroups.forEach(function (group) {
    $('.select2-choice').each(function (index, element) {
        var githubOwner = $(element).closest('td').prev().text().trim().split('/')[0];
        var gitlabOwner = `migrated/${group}`;
        var dropdownMenu = $(element).children().first();
        var gitlabGroup = $(`#select2-results-${index} .select2-result-label:contains(${gitlabOwner})`);
        var importButton = $(element).closest('td').parent().find('button:contains(Import)');

        if (githubOwner === group) {
            dropdownMenu.mousedown();
            gitlabGroup.mouseup();
            // uncomment only when the number of selected repos is small (<100),
            // otherwise GitLab runs into network issues, and repos fail to import.
            // Manually click "Import all repositories" instead.
            // importButton.click();
        }
    });
});
