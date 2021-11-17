// Modified by SNAC
$(function() {
  var $searchForm = $("#snac_search");

  var $results = $("#results");
  var $selected = $("#selected");

  var selected_snacids = {};

  var setRecordSelected = function($record) {
    var button = $("button.select-record", $record);
    button.addClass("selected");
    button.html(button.data("text-deselect"));

    $(".alert", $record).removeClass("alert-info").addClass("alert-success");
  };

  var setRecordDeselected = function($record) {
    var button = $("button.select-record", $record);
    button.removeClass("selected");
    button.html(button.data("text-select"));

    $(".alert", $record).removeClass("alert-success").addClass("alert-info");
  };

  var setRecordDetailsShown = function($record) {
    var button = $("button.show-record", $record);
    button.addClass("shown");
    button.html(button.data("text-hide"));

    $(".snac-show", $record).removeClass("hide").scrollTop(0);

    // load embedded iframe as well, if not already loaded
    var iframe = $(".snac-details-snippet", $record);
    if (!iframe.prop("src")) {
      iframe.prop("title", iframe.data("title"));
      iframe.prop("src", iframe.data("src"));
    }
  };

  var setRecordDetailsHidden = function($record) {
    var button = $("button.show-record", $record);
    button.removeClass("shown");
    button.html(button.data("text-show"));

    $(".snac-show", $record).addClass("hide");
  };

  var renderResults = function(json) {
    decorateResults(json);

    $results.empty();
    $results.append(AS.renderTemplate("template_snac_result_summary", json));
    $.each(json.records, function(i, record) {
      var $result = $(AS.renderTemplate("template_snac_result", {record: record}));

      setRecordDetailsHidden($result);
      if (selected_snacids[record.id]) {
        setRecordSelected($result);
      } else {
        setRecordDeselected($result);
      }

      $results.append($result);
    });

    $results.append(AS.renderTemplate("template_snac_pagination", json));
    $('.snac-show', $results).each(function(i, e) {hljs.highlightBlock(e)});
  };


  var decorateResults = function(resultsJson) {
    resultsJson.queryString = '?name_entry=' + resultsJson.query;
  };


  var selectedSnacIDs = function() {
    var result = [];
    $("[data-snacid]", $selected).each(function() {
      result.push($(this).data("snacid"));
    })
    return result;
  };


  var removeSelected = function(snacid) {
    selected_snacids[snacid] = false;
    $("[data-snacid="+snacid+"]", $selected).remove();

    var $result = $("[data-snacid="+snacid+"]", $results);
    if ($result.length > 0) {
      var $record = $result.closest(".snac-result");
      setRecordDeselected($record);
    }

    if (selectedSnacIDs().length === 0) {
      $selected.siblings(".alert-info").removeClass("hide");
      $("#import-selected").attr("disabled", "disabled");
    }
  };

  var addSelected = function(snacid, name, type) {
    if (selected_snacids[snacid]) {
      return;
    }

    selected_snacids[snacid] = true;
    $selected.append(AS.renderTemplate("template_snac_selected", {snacid: snacid, name: name, type: type}))
    $selected.siblings(".alert-info").addClass("hide");
    $("#import-selected").removeAttr("disabled", "disabled");
  };


  var resizeSelectedBox = function() {
    $selected.closest(".selected-container").width($selected.closest(".col-md-4").width() - 30);
  };


  $searchForm.ajaxForm({
    dataType: "json",
    type: "GET",
    beforeSubmit: function() {
      if (!$("#name-entry-search-query", $searchForm).val()) {
          return false;
      }

      $(".btn", $searchForm).attr("disabled", "disabled").addClass("disabled").addClass("busy");
    },
    success: function(json) {
      $(".btn", $searchForm).removeAttr("disabled").removeClass("disabled").removeClass("busy");
      if (json.error) {
        AS.openQuickModal(AS.renderTemplate("template_snac_search_error_title"), json.error);
      } else {
        renderResults(json);
      }
    },
    error: function(err) {
      $(".btn", $searchForm).removeAttr("disabled").removeClass("disabled").removeClass("busy");
      var errBody = err.hasOwnProperty("responseText") ? err.responseText.replace(/\n/g, "") : "<pre>" + JSON.stringify(err) + "</pre>";
      AS.openQuickModal(AS.renderTemplate("template_snac_search_error_title"), JSON.stringify(errBody));
    }
  });


  $results.on("click", ".snac-pagination a", function(event) {
    event.preventDefault();

    $.getJSON($(this).attr("href"), function(json) {
      $("body").scrollTo(0);
      renderResults(json);
    });
  }).on("click", ".snac-result button.select-record", function(e) {
    e.preventDefault();

    var $record = $(this).closest(".snac-result");
    var snacid = $(this).data("snacid");
    var name = $(this).data("name");
    var type = $(this).data("type");

    if ($(this).hasClass("selected")) {
      removeSelected(snacid);
      setRecordDeselected($record);
    } else {
      addSelected(snacid, name, type, $record);
      setRecordSelected($record);
    }
  }).on("click", ".snac-result button.show-record", function(e) {
    e.preventDefault();

    var $record = $(this).closest(".snac-result");

    if ($(this).hasClass("shown")) {
      setRecordDetailsHidden($record);
    } else {
      setRecordDetailsShown($record);
    }
  });

  $selected.on("click", ".remove-selected", function(event) {
    var snacid = $(this).parent().data("snacid");
    removeSelected(snacid);
  });


  $(window).resize(resizeSelectedBox);
  resizeSelectedBox();
})
