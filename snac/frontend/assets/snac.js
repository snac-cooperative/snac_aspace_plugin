// Modified by SNAC
$(function() {
  var $searchForm = $("#snac_search");
  var $importForm = $("#snac_import");

  var $results = $("#results");
  var $selected = $("#selected");

  var result_json = {};

  var selected_snacids = {};

  var renderResults = function(json) {
    decorateResults(json);

    $results.empty();
    $results.append(AS.renderTemplate("template_snac_result_summary", json));
    $.each(json.results, function(i, record) {
      var $result = $(AS.renderTemplate("template_snac_result", {record: record, selected: selected_snacids}));
      if (selected_snacids[record.id]) {
        $(".alert-success", $result).removeClass("hide");
      } else {
        $("button", $result).removeClass("hide");
      }
      $results.append($result);

    });
    //$results.append(AS.renderTemplate("template_snac_pagination", json));
    $('.snac-marc', $results).each(function(i, e) {hljs.highlightBlock(e)});
  };


  var decorateResults = function(resultsJson) {
    //stringify the query here so templates don't need
    //to worry about SRU vs OpenSearch
    if (typeof(resultsJson.query) === 'string') {
      // just use sru's family_name as the 
      // sole openSearch field
      resultsJson.queryString = '?family_name=' + resultsJson.query + '&snac_service=' + $("input[name='snac_service']:checked").val();
    } else {
       if ( resultsJson.query.query['local.GivenName'] === undefined ) {
        resultsJson.query.query['local.GivenName'] = "";  
      }
      resultsJson.queryString = '?family_name=' + resultsJson.query.query['local.FamilyName'] + '&given_name=' + resultsJson.query.query['local.GivenName'] + '&snac_service=' + $("input[name='snac_service']:checked").val();
    }
  }


  var selectedSNACIDs = function() {
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
      $result.removeClass("hide");
      $(".alert-success", $result).removeClass("alert-success").addClass("alert-info");
      $result.siblings(".alert").addClass("hide");
    }

    if (selectedSNACIDs().length === 0) {
      $selected.siblings(".alert-info").removeClass("hide");
      $("#import-selected").attr("disabled", "disabled");
    }
  };

  var addSelected = function(snacid, name, $result) {
    selected_snacids[snacid] = true;
    $selected.append(AS.renderTemplate("template_snac_selected", {snacid: snacid, name: name}))

    $(".alert-success", $result).removeClass("hide");
    $("button.select-record", $result).addClass("hide");
    $(".alert-info", $result).removeClass("alert-info").addClass("alert-success");

    $selected.siblings(".alert-info").addClass("hide");
    $("#import-selected").removeAttr("disabled", "disabled");
  };


  var resizeSelectedBox = function() {
    $selected.closest(".selected-container").width($selected.closest(".col-md-4").width() - 30);
  };

  var convertToMARC = function(data) {
    var xml = '<marcxml:record xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:marcxml="http://www.loc.gov/MARC21/slim" xmlns:mets="http://www.loc.gov/METS/" xmlns:mxe="http://www.loc.gov/mxe" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:skos="http://www.w3.org/2004/02/skos/core#" xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" xmlns:ri="http://id.loc.gov/ontologies/RecordInfo#" xmlns:sem="http://marklogic.com/semantics">'+"\n";
    xml += '<marcxml:controlfield tag="001">'+data.id+'</marcxml:controlfield>\n';
    xml += '  <marcxml:datafield tag="010" ind1=" " ind2=" ">\n' +
           '   <marcxml:subfield code="a">'+data.id+'</marcxml:subfield>\n' +
           ' </marcxml:datafield>\n';
    // if person: ind1=1 (surname) ind1=0 (forename only)  if family: ind1=3
      // a = personal name Last, First, b numeration, q fuller form, d dates, c titles
    xml += '  <marcxml:datafield tag="100" ind1="1" ind2=" ">'+
           '   <marcxml:subfield code="a">Linton, W. J.</marcxml:subfield>'+
           '   <marcxml:subfield code="q">(William James),</marcxml:subfield>'+
           '   <marcxml:subfield code="d">1812-1897</marcxml:subfield>'+
           ' </marcxml:datafield>';
    // if corpbody: ind1=2 (direct order)
      // a = name,  d dates
    xml += '  <marcxml:datafield tag="110" ind1="2" ind2=" ">'+
           '   <marcxml:subfield code="a">Corporate Name</marcxml:subfield>'+
           '   <marcxml:subfield code="d">1812-1897</marcxml:subfield>'+
           ' </marcxml:datafield>';
  }

  $searchForm.ajaxForm({
    dataType: "json",
    type: "GET",
    beforeSubmit: function() {
      if (!$("#family-name-search-query", $searchForm).val()) {
          return false;
      }

      $(".btn", $searchForm).attr("disabled", "disabled").addClass("disabled").addClass("busy");
    },
    success: function(json) {
      $(".btn", $searchForm).removeAttr("disabled").removeClass("disabled").removeClass("busy");
      renderResults(json);
      result_json = json;
    },
    error: function(err) {
      $(".btn", $searchForm).removeAttr("disabled").removeClass("disabled").removeClass("busy");
      var errBody = err.hasOwnProperty("responseText") ? err.responseText.replace(/\n/g, "") : "<pre>" + JSON.stringify(err) + "</pre>";
      AS.openQuickModal(AS.renderTemplate("template_snac_search_error_title"), JSON.stringify(errBody));
    }
  });


  $importForm.ajaxForm({
    dataType: "json",
    type: "POST",
    beforeSubmit: function(data, $form, options) {

      $("#import-selected").attr("disabled", "disabled").addClass("disabled").addClass("busy");

    },
    success: function(json) {
      $("#import-selected").removeClass("busy");
      if (json.job_uri) {
        AS.openQuickModal(AS.renderTemplate("template_snac_import_success_title"), AS.renderTemplate("template_snac_import_success_message"));
        setTimeout(function() {
          window.location = json.job_uri;
        }, 2000);
      } else {
        // error
        $("#import-selected").removeAttr("disabled").removeClass("busy")
        AS.openQuickModal(AS.renderTemplate("template_snac_import_error_title"), json.error);
      }
    },
    error: function(err) {
      $(".btn", $importForm).removeAttr("disabled").removeClass("disabled").removeClass("busy");
      var errBody = err.hasOwnProperty("responseText") ? err.responseText.replace(/\n/g, "") : "<pre>" + JSON.stringify(err) + "</pre>";
      AS.openQuickModal(AS.renderTemplate("template_snac_import_error_title"), JSON.stringify(errBody));
    }
  });


  $results.on("click", ".snac-pagination a", function(event) {
    event.preventDefault();

    $.getJSON($(this).attr("href"), function(json) {
      $("body").scrollTo(0); 
      renderResults(json);
    });
  }).on("click", ".snac-result button.select-record", function(event) {
    var snacid = $(this).data("snacid");
    var name = $(this).data("name");
    if (selected_snacids[snacid]) {
      removeSelected(snacid);
    } else {
      addSelected(snacid, name, $(this).closest(".snac-result"));
    }
  }).on("click", ".snac-result button.show-record", function(e) {
         e.preventDefault();
         $(this).siblings(".snac-marc").removeClass("hide");
         $(this).addClass("hide");     
  }); 

  $selected.on("click", ".remove-selected", function(event) {
    var snacid = $(this).parent().data("snacid");
    removeSelected(snacid);
  });



  $(window).resize(resizeSelectedBox);
  resizeSelectedBox();
})
