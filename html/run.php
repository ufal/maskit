<?php $main_page=basename(__FILE__); require('header.php') ?>

<script type="text/javascript"><!--
  var input_file_content = null;
  var output_file_content = null;
  var output_file_stats = null;
  var output_format = null;

  document.addEventListener("DOMContentLoaded", function() {
      getInfo();
      //console.log("DOM byl kompletně načten!");
  });

  function doSubmit() {
    //var model = jQuery('#model :selected').text();
    //if (!model) return;

    var input_text = jQuery('#input').val();
    //console.log("doSubmit: Input text: ", input_text);
    var input_format = jQuery('input[name=option_input]:checked').val();
    //console.log("doSubmit: Input format: ", input_format);
    output_format = jQuery('input[name=option_output]:checked').val();
    //console.log("doSubmit: Output format: ", output_format);
    // Zjistíme stav checkboxu s id "option-randomize"
    var options = {text: input_text, input: input_format, output: output_format};
    var jeZaskrtnutoRandomize = $('#option_randomize').prop('checked');
    //console.log("doSubmit: Randomize: ", jeZaskrtnutoRandomize);
    // Přidáme parametr "randomize", pokud je checkbox zaškrtnutý
    if (jeZaskrtnutoRandomize) {
      options.randomize = null; // Nebo prázdný řetězec, záleží na konkrétní implementaci serveru
    }
    // Zjistíme stav checkboxu s id "option-classes"
    var jeZaskrtnutoClasses = $('#option_classes').prop('checked');
    //console.log("doSubmit: Replace with classes: ", jeZaskrtnutoClasses);
    // Přidáme parametr "classes", pokud je checkbox zaškrtnutý
    if (jeZaskrtnutoClasses) {
      options.classes = null; // Nebo prázdný řetězec, záleží na konkrétní implementaci serveru
    }
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
              displayFormattedOutput();
	  }
	  if ("stats" in json) {
              output_file_stats = json.stats;
              jQuery('#output_stats').html(output_file_stats);
	  }

      } catch(e) {
        jQuery('#submit').html('<span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span>');
        jQuery('#submit').prop('disabled', false);
      }
    }, error: function(jqXHR, textStatus) {
      alert("An error occurred" + ("responseText" in jqXHR ? ": " + jqXHR.responseText : "!"));
    }, complete: function() {
      jQuery('#submit').html('<span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span>');
      jQuery('#submit').prop('disabled', false);
    }});
  }

  
  function getInfo() { // call the server and get the MasKIT version and a list of supported features

    var options = {info: null};
    //console.log("getInfo: options: ", options);

    var form_data = null;
    if (window.FormData) {
      form_data = new FormData();
      for (var key in options)
        form_data.append(key, options[key]);
    }

    var version = '<?php echo $lang[$currentLang]['run_server_info_version_unknown']; ?> (<font color="red"><?php echo $lang[$currentLang]['run_server_info_status_error']; ?>!</font>)';
    var features = '<?php echo $lang[$currentLang]['run_server_info_features_unknown']; ?>';
    //console.log("Calling api/info");
    jQuery.ajax('//quest.ms.mff.cuni.cz/ponk/api/info',
           {data: form_data ? form_data : options, processData: form_data ? false : true,
            contentType: form_data ? false : 'application/x-www-form-urlencoded; charset=UTF-8',
            dataType: "json", type: "POST", success: function(json) {
      try {
        if ("version" in json) {
		version = json.version;
		version += ', <span style="font-style: normal"><?php echo $lang[$currentLang]['run_server_info_status']; ?>:</span> <font color="green">online</font>';
		//console.log("json.version: ", version);
        }
        if ("features" in json) {
              features = json.features;
        }

      } catch(e) {
        // no need to do anything
      }
    }, error: function(jqXHR, textStatus) {
      console.log("An error occurred " + ("responseText" in jqXHR ? ": " + jqXHR.responseText : "!"));
    }, complete: function() {
      //console.log("Complete.");
      var info = "<h4><?php echo $lang[$currentLang]['run_server_info_label']; ?></h4>\n<ul><li><?php echo $lang[$currentLang]['run_server_info_version']; ?>: <i>" + version + "</i>\n<li><?php echo $lang[$currentLang]['run_server_info_features']; ?>: <i>" + features + "</i>\n</ul>\n";
      jQuery('#server_info').html(info).show();
      //console.log("Info: ", info);
      var short_info = "&nbsp; <?php echo $lang[$currentLang]['run_server_info_version']; ?>: <i>" + version + "</i>";
      jQuery('#server_short_info').html(short_info).show();
      //console.log("Info: ", info);
      
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
    var formatted_output = formatOutput();
    var content_blob = new Blob([formatted_output], {type: output_format == "html" ? "text/html" : "text/plain"});
    saveAs(content_blob, "citations." + output_format);
  }

  function saveStats() {
    if (!output_file_stats) return;
    var stats_blob = new Blob([output_file_stats], {type: "text/html"});
    saveAs(stats_blob, "statistics.html");
  }
  
  function removeOriginals(text) { // z výsledného textu v daném formátu vyhodí originální údaje
    if (output_format === 'html') {
      var tempDiv = document.createElement('div'); // Vytvořte dočasný element (např. div)
      tempDiv.innerHTML = text; // nastavte jeho vnitřní HTML kód na daný text
      var spansToRemove = tempDiv.querySelectorAll('.orig-brackets'); // Získejte všechny elementy span s danou třídou.
      spansToRemove.forEach(function(span) { // Projděte všechny získané elementy a odstraňte je
        span.parentNode.removeChild(span);
      });
      var finalResult = tempDiv.innerHTML; // Získejte konečný HTML kód bez elementů span dané třídy.
      return finalResult;
    }
    else if (output_format === 'txt') {
      var regex = /_\[[^\]]*\]/g; // Použití regulárního výrazu pro hledání textu mezi "_[" a "]"
      var vysledek = text.replace(regex, ''); // Nahrazení nalezeného textu prázdným řetězcem
      return vysledek;
    }
    return text; // při nerozpoznání formátu vracím nezměněný text
  }


  function removeHighlighting(text) { // z textu vyhodí zvýraznění doplněných údajů
    if (output_format === 'txt') {
      return text;
    }
    else if (output_format === 'html') { 
      var tempDiv = document.createElement('div'); // Vytvořte dočasný element (např. div)
      tempDiv.innerHTML = text; // a nastavte jeho vnitřní HTML kód na příslušný obsah
      var spansToRemove = tempDiv.querySelectorAll('.replacement-text'); // Získání všech elementů span s danou třídou
      spansToRemove.forEach(function(span) { // Projděte všechny získané elementy a nahraďte je jejich textovým obsahem
        var textNode = document.createTextNode(span.textContent);
        span.parentNode.replaceChild(textNode, span);
      });
      var finalText = tempDiv.innerHTML; // Získejte konečný text bez elementů span
      //console.log(finalText);
      return finalText;
    }
    return text; // při nerozpoznání formátu vracím nezměněný text
  }


  function formatOutput() { 
    var formatted_output;  
    // Nejprve checkbox pro zobrazování originálných výrazů
    var checkbox = document.getElementById("origsCheckbox");
    if (checkbox.checked) { // zobrazím původní výsledný text (vč. originálů)
      formatted_output = output_file_content;
    } else { // vyhodím z výsledného textu originály
      formatted_output = removeOriginals(output_file_content);
    }
    // Nyní checkbox pro barevné zvýraznění nových výrazů
    checkbox = document.getElementById("highlightingCheckbox");
    if (checkbox.checked) { // zobrazím původní výsledný text (vč. barevného zvýraznění)
      // nedělám nic
    } else { // vyhodím z výsledného textu barevné zvýraznění nových výrazů
      formatted_output = removeHighlighting(formatted_output);
    }
    return formatted_output;
  }


  function displayFormattedOutput() { // zobrazí output_file_content podle parametrů nastavených checkboxy
    var formatted_output = formatOutput();
    // Přidání <br> ke každému novému řádku v proměnné with_or_without_origs
    var formatted_content = output_format == "html" ? formatted_output : formatted_output.replace(/\n/g, "\n<br>");
    //console.log(formatted_content);
    jQuery('#output_formatted').html(formatted_content);
  }


  function handleOutputFormatChange() {
      //console.log("handleOutputFormatChange - entering the function");
      var txtRadio = document.getElementById("option_output_txt");
      var htmlRadio = document.getElementById("option_output_html");
      var checkbox = document.getElementById("highlightingCheckbox");

      if (txtRadio.checked) {
        // Zneaktivní checkbox při výběru TXT radio tlačítka
        //console.log("handleOutputFormatChange - disabling the checkbox");
        checkbox.disabled = true;
      } else if (htmlRadio.checked) {
        // Zaktivní checkbox při výběru HTML radio tlačítka
        //console.log("handleOutputFormatChange - enabling the checkbox");
        checkbox.disabled = false;
      }
  }


  function handleRandomizeChanged() {
    //console.log("handleRandomizeChanged - entering the function");
    var optionRandomize = document.getElementById('option_randomize');
    if (optionRandomize.checked) {
      var optionClasses = document.getElementById('option_classes');
      optionClasses.checked = false;
    }
  }

  function handleClassesChanged() {
    //console.log("handleClassesChanged - entering the function");
    var optionClasses = document.getElementById('option_classes');
    if (optionClasses.checked) {
      var optionRandomize = document.getElementById('option_randomize');
      optionRandomize.checked = false;
    }
  }



--></script>

<div class="panel panel-default">
  <div class="panel-heading" role="tab" id="aboutHeading">
    <div class="collapsed" role="button" data-toggle="collapse" href="#aboutContent" aria-expanded="false" aria-controls="aboutContent">
      <span class="glyphicon glyphicon-triangle-bottom" aria-hidden="true"></span> <?php echo $lang[$currentLang]['run_about_line']; ?>
    </div>
  </div>
  <div id="aboutContent" class="panel-collapse collapse" role="tabpanel" aria-labelledby="aboutHeading">

          <?php
            if ($currentLang == 'cs') {
          ?>
    <div style="margin: 5px"><?php require('about_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div style="margin: 5px"><?php require('about_en.html') ?></div>
          <?php
            }
          ?>

  </div>
</div>

  <div class="panel panel-default">
    <div class="panel-heading" role="tab" id="serverInfoHeading">
      <div class="collapsed" role="button" data-toggle="collapse" href="#serverInfoContent" aria-expanded="false" aria-controls="serverInfoContent">
        <span class="glyphicon glyphicon-triangle-bottom" aria-hidden="true"></span> <?php echo $lang[$currentLang]['run_server_info_label']; ?>: <span id="server_short_info" style="display: none"></span>
      </div>
    </div>
    <div id="serverInfoContent" class="panel-collapse collapse" role="tabpanel" aria-labelledby="serverInfoHeading">

      <div style="margin: 5px">

    <div id="server_info" style="display: none"></div>
  
          <?php
            if ($currentLang == 'cs') {
          ?>
    <div><?php require('licence_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div><?php require('licence_en.html') ?></div>
          <?php
            }
          ?>

        <p><?php echo $lang[$currentLang]['run_server_info_word_limit']; ?></p>
     <div id="error" class="alert alert-danger" style="display: none"></div>
     </div>
  </div>

  <!-- ================= OPTIONS ================ -->

    <div class="form-horizontal">
      <div class="form-group row" style="margin-top: 10px; margin-bottom: 0px">
        <label class="col-sm-2 control-label"><?php echo $lang[$currentLang]['run_options_input_label']; ?>:</label>
        <div class="col-sm-10">
          <label title="<?php echo $lang[$currentLang]['run_options_input_plain_popup']; ?>" class="radio-inline" id="option_input_plaintext"><input name="option_input" type="radio" value="txt" checked/><?php echo $lang[$currentLang]['run_options_input_plain']; ?></label>
          <label title="<?php echo $lang[$currentLang]['run_options_input_presegmented_popup']; ?>" class="radio-inline" id="option_input_presegmented"><input name="option_input" type="radio" value="presegmented"/><?php echo $lang[$currentLang]['run_options_input_presegmented']; ?> (<a href="http://ufal.mff.cuni.cz/maskit/users-manual#run_maskit_input" target="_blank"><?php echo $lang[$currentLang]['run_options_input_presegmented_note']; ?></a>)</label>
        </div>
      </div>
      <div class="form-group row" style="margin-top: 0px; margin-bottom: 0px">
        <label class="col-sm-2 control-label"><?php echo $lang[$currentLang]['run_options_output_label']; ?>:</label>
	<div class="col-sm-10">
          <label title="<?php echo $lang[$currentLang]['run_options_output_txt_popup']; ?>" class="radio-inline">
            <input name="option_output" type="radio" value="txt" id="option_output_txt" onchange="handleOutputFormatChange();"/><?php echo $lang[$currentLang]['run_options_output_txt']; ?>
            (<a href="http://ufal.mff.cuni.cz/maskit/users-manual#run_maskit_output" target="_blank"><?php echo $lang[$currentLang]['run_options_output_txt_note']; ?></a>)
          </label>
          <label title="<?php echo $lang[$currentLang]['run_options_output_html_popup']; ?>" class="radio-inline">
            <input name="option_output" type="radio" value="html" id="option_output_html" checked onchange="handleOutputFormatChange();"/><?php echo $lang[$currentLang]['run_options_output_html']; ?> (<a href="http://ufal.mff.cuni.cz/maskit/users-manual#run_maskit_output" target="_blank"><?php echo $lang[$currentLang]['run_options_output_html_note']; ?></a>)
          </label>
        </div>
      </div>
      <div class="form-group row" style="margin-top: 0px">
        <label class="col-sm-2 control-label"><?php echo $lang[$currentLang]['run_options_options_label']; ?>:</label>
        <div class="col-sm-10">
          <label title="<?php echo $lang[$currentLang]['run_options_options_randomize_popup']; ?>" class="checkbox-inline" id="option_randomize_label"><input id="option_randomize" name="option_randomize" type="checkbox" checked onchange="handleRandomizeChanged();"/><?php echo $lang[$currentLang]['run_options_options_randomize']; ?></label>
          <label title="<?php echo $lang[$currentLang]['run_options_options_classes_popup']; ?>" class="checkbox-inline" id="option_classes_label"><input id="option_classes" name="option_classes" type="checkbox" onchange="handleClassesChanged();"/><?php echo $lang[$currentLang]['run_options_options_classes']; ?></label>
        </div>
      </div>
    </div>

    <!-- ================= INPUT FIELDS ================ -->

    <ul class="nav nav-tabs nav-justified nav-tabs-green">
     <li class="active" style="position:relative"><a href="#input_text" data-toggle="tab"><span class="fa fa-font"></span> <?php echo $lang[$currentLang]['run_input_text']; ?></a>
          <button type="button" class="btn btn-primary btn-xs" style="position:absolute; top: 11px; right: 10px; padding: 0 2em" onclick="var t=document.getElementById('input'); t.value=''; t.focus();"><?php echo $lang[$currentLang]['run_input_text_button_delete']; ?></button>
     </li>
    </ul>

    
    <div class="tab-content" id="input_tabs" style="border-right: 1px solid #ddd; border-left: 1px solid #ddd; border-bottom: 1px solid #ddd; border-bottom-right-radius: 5px; border-bottom-left-radius: 5px; padding: 15px">
     <div class="tab-pane active" id="input_text">
      <textarea id="input" class="form-control" rows="10" cols="80"></textarea>
     </div>
    </div>

    <button id="submit" class="btn btn-primary form-control" type="submit" style="margin-top: 15px; margin-bottom: 15px" onclick="doSubmit()"><span class="fa fa-arrow-down"></span> <?php echo $lang[$currentLang]['run_process_input']; ?> <span class="fa fa-arrow-down"></span></button>

    <!-- ================= OUTPUT FIELDS ================ -->

    <ul class="nav nav-tabs nav-justified nav-tabs-green">
     <li class="active" style="position:relative">
	  <a href="#output_formatted" data-toggle="tab"><span class="fa fa-font"></span> <?php echo $lang[$currentLang]['run_output_text']; ?></a>
          <div style="position:absolute; top: 6px; left: 10px; padding: 0 0em; border: none;">
            <div style="display: flex; flex-direction: row;">
              <div style="display: flex; flex-direction: column; align-items: center; margin-right: 8px;">
                <input title="<?php echo $lang[$currentLang]['run_output_text_check_origs_popup']; ?>" type="checkbox" checked id="origsCheckbox" onchange="displayFormattedOutput();">
                <span style="font-size: 60%; font-weight: normal; margin-top: 2px;"><?php echo $lang[$currentLang]['run_output_text_check_origs']; ?></span>
              </div>
              <div style="display: flex; flex-direction: column; align-items: center;">
                <input title="<?php echo $lang[$currentLang]['run_output_text_check_colours_popup']; ?>" type="checkbox" checked id="highlightingCheckbox" onchange="displayFormattedOutput();">
                <span style="font-size: 60%; font-weight: normal; margin-top: 2px;"><?php echo $lang[$currentLang]['run_output_text_check_colours']; ?></span>
              </div>
            </div>
          </div>
          <button type="button" class="btn btn-primary btn-xs" style="position:absolute; top: 11px; right: 10px; padding: 0 2em" onclick="saveOutput();"><span class="fa fa-download"></span> <?php echo $lang[$currentLang]['run_output_text_button_save']; ?></button>
     </li>
     <li style="position:relative"><a href="#output_stats" data-toggle="tab"><span class="fa fa-table"></span> <?php echo $lang[$currentLang]['run_output_statistics']; ?></a>
          <button type="button" class="btn btn-primary btn-xs" style="position:absolute; top: 11px; right: 10px; padding: 0 2em" onclick="saveStats();"><span class="fa fa-download"></span> <?php echo $lang[$currentLang]['run_output_statistics_button_save']; ?></button>
     </li>
    </ul>

    <div class="tab-content" id="output_tabs" style="border-right: 1px solid #ddd; border-left: 1px solid #ddd; border-bottom: 1px solid #ddd; border-bottom-right-radius: 5px; border-bottom-left-radius: 5px; padding: 15px">
     <div class="tab-pane active" id="output_formatted">
     </div>
     <div class="tab-pane" id="output_stats">
     </div>
    </div>

    <div style="margin: 5px">

          <?php
            if ($currentLang == 'cs') {
          ?>
    <div><?php include('acknowledgements_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div><?php include('acknowledgements_en.html') ?></div>
          <?php
            }
          ?>


    </div>
</div>

<?php require('footer.php') ?>
