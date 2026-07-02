var CompassCardDownload = (function() {
    function assertTitle(title) {
        return document.title == title;
    }
    function assertTitles(title1, title2) {
        return document.title == title1 || document.title == title2;
    }
    function enterField(selector, input) {
        let element = document.body.querySelector(selector);
        element.value = input;
        element.dispatchEvent(new Event('input'));
    }
    function clickSubmitButton() {
        document.body.querySelector("#Content_btnSignIn").click();
    }
    function getTitle() {
        return document.title
    }
    function getContent() {
        return document.body.innerText;
    }
    function getText(selector) {
        return document.body.querySelector(selector).innerText;
    }
    return {
        assertTitle: assertTitle,
        assertTitles: assertTitles,
        enterField: enterField,
        clickSubmitButton: clickSubmitButton,
        getTitle: getTitle,
        getContent: getContent,
        getText: getText
    };
})()
