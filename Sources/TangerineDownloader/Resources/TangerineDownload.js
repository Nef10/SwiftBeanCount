var TangerineDownload = (function() {
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
    function toggleRememberMe() {
        document.body.querySelector("#login-user-id-remember-me-toggle-input").click();
    }
    function clickSubmitButton() {
        document.body.querySelector("button[type='submit']").click();
    }
    function getTitle() {
        return document.title
    }
    function getContent() {
        return JSON.parse(document.body.innerText);
    }
    return {
        assertTitle: assertTitle,
        assertTitles: assertTitles,
        enterField: enterField,
        toggleRememberMe: toggleRememberMe,
        clickSubmitButton: clickSubmitButton,
        getTitle: getTitle,
        getContent: getContent
    };
})()
