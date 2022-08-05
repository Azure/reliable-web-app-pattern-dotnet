(function ($) {

    function setVisibilityForTicketManagementFields(selectedValue) {
        $('[data-ticket-management-fields]').hide();
        $('[data-ticket-management-fields="' + selectedValue + '"]').show();
    }

    $('#Concert_TicketManagementServiceProvider').change(function (e) {
        var selectedValue = e.target.options[e.target.selectedIndex].value;
        setVisibilityForTicketManagementFields(selectedValue);
    });

    $(document).ready(function () {
        var selectedValue = $('#Concert_TicketManagementServiceProvider').val();
        setVisibilityForTicketManagementFields(selectedValue);
    });
})(jQuery);