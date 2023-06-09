// Please see documentation at https://learn.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

// Write your JavaScript code.
$(document).ready(function () {
    $("#query").autocomplete({
        source: function (request, response) {
            $.ajax({
                type: "GET",
                url: "/concert/suggest",
                contentType: "application/json",
                data: {
                    query: request.term
                }
            })
                .done(function (data) {
                    response(data);
                });
        },
        minLength: 3
    });
});