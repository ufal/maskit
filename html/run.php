<?php $main_page=basename(__FILE__); require('header.php') ?>

<?php require('about.html') ?>

<script type="text/javascript"><!--
  var input_file_content = null;
  var output_file_content = null;
  var output_file_stats = null;
  var output_format = null;

  function doSubmit() {
    //var model = jQuery('#model :selected').text();
    //if (!model) return;

    var input_text = jQuery('#input').val();
    // console.log("doSubmit: Input text: ", input_text);
    var input_format = jQuery('input[name=option_input]:checked').val();
    // console.log("doSubmit: Input format: ", input_format);
    output_format = jQuery('input[name=option_output]:checked').val();
    // console.log("doSubmit: Output format: ", output_format);
    var options = {text: input_text, input: input_format, output: output_format};
    // console.log("doSubmit: options: ", options);

    var form_data = null;
    if (window.FormData) {
      form_data = new FormData();
      for (var key in options)
        form_data.append(key, options[key]);
    }

    output_file_content = null;
    jQuery('#output_formatted').empty();
    jQuery('#output_stats').empty();
    jQuery('#submit').html('<span class="fa fa-cog"></span> Waiting for Results <span class="fa fa-cog"></span>');
    jQuery('#submit').prop('disabled', true);
    jQuery.ajax('//quest.ms.mff.cuni.cz/maskit/api/process',
           {data: form_data ? form_data : options, processData: form_data ? false : true,
            contentType: form_data ? false : 'application/x-www-form-urlencoded; charset=UTF-8',
            dataType: "json", type: "POST", success: function(json) {
      try {
	  if ("result" in json) {
              output_file_content = json.result;
	      var with_or_without_origs = changeOrigs();
	      // Přidání <br> ke každému novému řádku v proměnné with_or_without_origs
              var formatted_content = output_format == "html" ? with_or_without_origs : with_or_without_origs.replace(/\n/g, "\n<br>");
              jQuery('#output_formatted').html(formatted_content);
	  }
	  if ("stats" in json) {
              output_file_stats = json.stats;
              jQuery('#output_stats').html(output_file_stats);
	  }

      } catch(e) {
        jQuery('#submit').html('<span class="fa fa-arrow-down"></span> Process Input <span class="fa fa-arrow-down"></span>');
        jQuery('#submit').prop('disabled', false);
      }
    }, error: function(jqXHR, textStatus) {
      alert("An error occurred" + ("responseText" in jqXHR ? ": " + jqXHR.responseText : "!"));
    }, complete: function() {
      jQuery('#submit').html('<span class="fa fa-arrow-down"></span> Process Input <span class="fa fa-arrow-down"></span>');
      jQuery('#submit').prop('disabled', false);
    }});
  }

  function saveAs(blob, file_name) {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = file_name;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
  }

  function saveOutput() {
    if (!output_file_content || !output_format) return;
    var content_blob = new Blob([output_file_content], {type: output_format == "html" ? "text/html" : "text/plain"});
    saveAs(content_blob, "citations." + output_format);
  }

  function saveStats() {
    if (!output_file_stats) return;
    var stats_blob = new Blob([output_file_stats], {type: "text/html"});
    saveAs(stats_blob, "statistics.html");
  }
  
  function removeOriginals() { // z výsledného textu v daném formátu vyhodí originální údaje
    if (output_format == 'html') {
      var tempDiv = document.createElement('div'); // Vytvořte dočasný element (např. div)
      tempDiv.innerHTML = output_file_content; // nastavte jeho vnitřní HTML kód na daný text
      var spansToRemove = tempDiv.querySelectorAll('.orig-brackets'); // Získejte všechny elementy span s danou třídou.
      spansToRemove.forEach(function(span) { // Projděte všechny získané elementy a odstraňte je
        span.parentNode.removeChild(span);
      });
      var finalResult = tempDiv.innerHTML; // Získejte konečný HTML kód bez elementů span dané třídy.
      return finalResult;
    }
    else if (output_format == 'txt') {
      var regex = /_\[[^\]]*\]/g; // Použití regulárního výrazu pro hledání textu mezi "_[" a "]"
      var vysledek = output_file_content.replace(regex, ''); // Nahrazení nalezeného textu prázdným řetězcem
      return vysledek;
    }
    return output_file_content; // při nerozpoznání formátu vracím původní text
  }


  function changeOrigs() { // volána použitím checkboxu origsCheckbox - zapne či vypne zobrazení originálních údajů
    var checkbox = document.getElementById("origsCheckbox");
    if (checkbox.checked) { // zobrazím původní výsledný text (vč. originálů)
      //console.log("Checkbox byl zaškrtnut.");
      var formatted_content = output_format == "html" ? output_file_content : output_file_content.replace(/\n/g, "\n<br>");
      //console.log(formatted_content);
      jQuery('#output_formatted').html(formatted_content);
    } else { // vyhodím z výsledného textu originály
      //console.log("Checkbox byl odškrtnut.");
      var output_without_origs = removeOriginals();
      var formatted_content = output_format == "html" ? output_without_origs : output_without_origs.replace(/\n/g, "\n<br>");
      //console.log(formatted_content);
      jQuery('#output_formatted').html(formatted_content);
    }
  }


--></script>

<div class="panel panel-info">
  <div class="panel-heading">Service</div>
  <div class="panel-body">

    <?php require('licence.html') ?>
    <p>Please note that due to time limitations on our proxy server, the maximum length for input text is approximately 5 thousand words.</p>


    <div id="error" class="alert alert-danger" style="display: none"></div>

    <div class="form-horizontal">
      <div class="form-group row">
        <label class="col-sm-2 control-label">Input:</label>
        <div class="col-sm-10">
          <label title="Tokenize input using a tokenizer" class="radio-inline" id="option_input_plaintext"><input name="option_input" type="radio" value="txt" checked/>Plain text</label>
          <label title="Tokenize a pre-segmented input using a tokenizer" class="radio-inline" id="option_input_presegmented"><input name="option_input" type="radio" value="presegmented"/>Pre-segmented (<a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec_input" target="_blank">sentence per line</a>)</label>
        </div>
      </div>
      <div class="form-group row">
        <label class="col-sm-2 control-label">Output:</label>
        <div class="col-sm-10">
          <label title="TXT with sources and phrases marked with special characters" class="radio-inline" id="option_output_txt"><input name="option_output" type="radio" value="txt"/>TXT (<a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec_output" target="_blank">marked with special characters</a>)</label>
          <label title="HTML with colour-marked sources and phrases" class="radio-inline" id="option_output_html"><input name="option_output" type="radio" value="html" checked/>HTML (<a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec_output" target="_blank">colour-marked</a>)</label>
          <!--label title="CoNLL-U format with sources and phrases in MISC" class="radio-inline" id="option_output_conllu"><input name="option_output" type="radio" value="conllu"/>CoNLL-U (<a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec_output" target="_blank">CoNLL-U+NE+SD</a>)</label-->
        </div>
      </div>
    </div>

    <ul class="nav nav-tabs nav-justified nav-tabs-green">
     <li class="active" style="position:relative"><a href="#input_text" data-toggle="tab"><span class="fa fa-font"></span> Input Text</a>
          <button type="button" class="btn btn-primary btn-xs" style="position:absolute; top: 11px; right: 10px; padding: 0 2em" onclick="var t=document.getElementById('input'); t.value=''; t.focus();">Delete input text</button>
     </li>
    </ul>

    
    <div class="tab-content" id="input_tabs" style="border-right: 1px solid #ddd; border-left: 1px solid #ddd; border-bottom: 1px solid #ddd; border-bottom-right-radius: 5px; border-bottom-left-radius: 5px; padding: 15px">
     <div class="tab-pane active" id="input_text">
      <textarea id="input" class="form-control" rows="10" cols="80"></textarea>
     </div>
    </div>

    <button id="submit" class="btn btn-primary form-control" type="submit" style="margin-top: 15px; margin-bottom: 15px" onclick="doSubmit()"><span class="fa fa-arrow-down"></span> Process Input <span class="fa fa-arrow-down"></span></button>

    <ul class="nav nav-tabs nav-justified nav-tabs-green">
     <li class="active" style="position:relative">
          <a href="#output_formatted" data-toggle="tab"><span class="fa fa-font"></span> Output</a>
          <input type="checkbox" checked style="position:absolute; top: 11px; left: 10px; padding: 0 2em" id="origsCheckbox" onchange="changeOrigs()">
          <button type="button" class="btn btn-primary btn-xs" style="position:absolute; top: 11px; right: 10px; padding: 0 2em" onclick="saveOutput();"><span class="fa fa-download"></span> Save</button>
     </li>
     <li style="position:relative"><a href="#output_stats" data-toggle="tab"><span class="fa fa-table"></span> Statistics</a>
          <button type="button" class="btn btn-primary btn-xs" style="position:absolute; top: 11px; right: 10px; padding: 0 2em" onclick="saveStats();"><span class="fa fa-download"></span> Save</button>
     </li>
    </ul>

    <div class="tab-content" id="output_tabs" style="border-right: 1px solid #ddd; border-left: 1px solid #ddd; border-bottom: 1px solid #ddd; border-bottom-right-radius: 5px; border-bottom-left-radius: 5px; padding: 15px">
     <div class="tab-pane active" id="output_formatted">
     </div>
     <div class="tab-pane" id="output_stats">
     </div>
    </div>

    <h3 id="acknowledgements_title" style="margin-top: 30px">Acknowledgements</h3>
    <p id="acknowledgements_text">The development of MasKIT was financed by the TAČR SIGMA project TQ01000526: PONK - Asistent přístupné úřední komunikace.</p>
    <p>MasKIT uses external services for its work:
    <ul>
      <li>
        UDPipe (<a href="https://lindat.mff.cuni.cz/services/udpipe/" target="_blank">https://lindat.mff.cuni.cz/services/udpipe/</a>)
      </li>
      <li>
        NameTag (<a href="http://lindat.mff.cuni.cz/services/nametag/" target="_blank">http://lindat.mff.cuni.cz/services/nametag/</a>)
      </li>
    </ul>
    <p> 
      This work has been using language resources developed, stored or distributed by the LINDAT/CLARIAH-CZ project of the Ministry of Education of the Czech Republic (project <i>LM2023062</i>).
    </p>
  </div>
</div>

<?php require('footer.php') ?>
