
<!-- Reading logs and preparation of a chart with access numbers for several past months -->

<?php
$monthsBack = 6; // Počet měsíců zpět (vč. aktuálního), lze změnit
$logsDir = __DIR__ . '/log'; // Cesta k adresáři s logy
$logFilesPattern = 'api.log*'; // Vzor pro soubory (api.log, api.log.1, api.log.2.gz atd.)

// Získání aktuálního data (pro simulaci použijte zadané datum, v reálu date('Y-m-d H:i:s'))
//$now = new DateTime('2025-08-15');
$now = new DateTime();
$cutoffDate = (clone $now)->modify("-$monthsBack months")->setDate($now->format('Y'), $now->format('m') - $monthsBack + 1, 1); // První den nejstaršího měsíce

// Inicializace počtů přístupů
$accessCounts = [];
for ($i = 0; $i < $monthsBack; $i++) {
    $d = (clone $now)->modify("-$i months");
    $yearMonth = $d->format('Y-m');
    $accessCounts[$yearMonth] = 0;
}

// Načtení souborů pomocí glob
$logFiles = glob("$logsDir/$logFilesPattern");
//if (empty($logFiles)) {
//    die('Žádné logovací soubory nenalezeny.');
//}

// Zpracování každého souboru
foreach ($logFiles as $file) {
    if (pathinfo($file, PATHINFO_EXTENSION) === 'gz') {
        // Komprimovaný soubor
        $handle = gzopen($file, 'r');
        if (!$handle) continue;
        while (($line = gzgets($handle)) !== false) {
            processLine($line, $cutoffDate, $accessCounts);
        }
        gzclose($handle);
    } else {
        // Nekomprimovaný soubor
        $handle = fopen($file, 'r');
        if (!$handle) continue;
        while (($line = fgets($handle)) !== false) {
            processLine($line, $cutoffDate, $accessCounts);
        }
        fclose($handle);
    }
}

// Funkce pro zpracování řádku
function processLine($line, $cutoffDate, &$accessCounts) {
    $line = trim($line);
    if (empty($line)) return;

    $parts = explode("\t", $line);
    if (count($parts) < 1) return;

    $dateStr = $parts[0];
    $logDate = DateTime::createFromFormat('D M d H:i:s Y', $dateStr);
    if (!$logDate) return; // Neplatné datum

    if ($logDate >= $cutoffDate) {
        $yearMonth = $logDate->format('Y-m');
        if (isset($accessCounts[$yearMonth])) {
            $accessCounts[$yearMonth]++;
        }
    }
}

// Příprava dat pro graf
$labels = array_keys($accessCounts);
sort($labels); // Vzestupně (nejstarší napřed)
$data = [];
foreach ($labels as $label) {
    $data[] = $accessCounts[$label];
}
$labelsJson = json_encode($labels);
$dataJson = json_encode($data);
?>


<script type="text/javascript"><!--
  var input_file_content = null;
  var output_file_content = null;
  var output_file_stats = null;
  var output_format = null;

  var output_display_colours = 1;
  var output_display_originals = 1;


  document.addEventListener("DOMContentLoaded", function() {
    //console.log("DOM byl kompletně načten!");
    displayShortSelectedOptions(); // display default settings at the info bar
    getInfo();
    createAccessCountChart();

    const textarea = document.getElementById('input');
    let originalValue = textarea.value;

    textarea.addEventListener('focus', function() {
      if (this.value === originalValue) {
        this.value = '';
        this.style.color = '#333333'; // Změní barvu na tmavou při psaní
      }
    });

    // Nastavení barvy pro předvyplněný text při načtení
    textarea.style.color = '#bbbbbb';
  });


  // Calling the SERVER:

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

    jQuery('#submit').html('<span class="spinner-border spinner-border-sm" style="width: 1.2rem; height: 1.2rem;" role="status" aria-hidden="true"></span>&nbsp;<?php echo $lang[$currentLang]['run_process_input_processing']; ?>&nbsp;<span class="spinner-border spinner-border-sm" style="width: 1.2rem; height: 1.2rem; animation-direction: reverse;" role="status" aria-hidden="true"></span>');
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
      jQuery('#submit').html('<span class="fa fa-arrow-down"></span>&nbsp;<?php echo $lang[$currentLang]['run_process_input']; ?>&nbsp;<span class="fa fa-arrow-down"></span>');
      jQuery('#submit').prop('disabled', false);
    }});
  }

  function createAccessCountChart () {
        const ctx = document.getElementById('accessChart').getContext('2d');
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: <?php echo $labelsJson; ?>,
                datasets: [{
                    label: '<?php echo $lang[$currentLang]['run_server_access_chart_column_label']; ?> ',
                    data: <?php echo $dataJson; ?>,
                    backgroundColor: '#36A2EB',
                    borderColor: '#1E87D6',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: false, /* Zakázáno pro pevnou velikost */
                animation: false, /* Zakázání animací */
                plugins: {
                    legend: {
                        position: 'top',
                        labels: {
                            color: '#333',
                            font: { size: 12 }
                        }
                    },
                    //title: {
                    //    display: true,
                    //    text: 'Počet přístupů za poslední měsíce',
                    //    color: '#333',
                    //    font: { size: 14 }
                    //}
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        //title: {
                        //    display: true,
                        //    text: 'Počet přístupů',
                        //    color: '#333',
                        //    font: { size: 12 }
                        //},
                        ticks: { color: '#333', font: { size: 10 } }
                    },
                    x: {
                        //title: {
                        //    display: true,
                        //    text: 'Měsíc',
                        //    color: '#333',
                        //    font: { size: 12 }
                        //},
                        ticks: { color: '#333', font: { size: 10 } }
                    }
                }
            }
        });

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
    jQuery.ajax('//quest.ms.mff.cuni.cz/maskit/api/info',
           {data: form_data ? form_data : options, processData: form_data ? false : true,
            contentType: form_data ? false : 'application/x-www-form-urlencoded; charset=UTF-8',
            dataType: "json", type: "POST", success: function(json) {
      try {
        if ("version" in json) {
		version = json.version;
		version += ', <span style="font-style: normal"><?php echo $lang[$currentLang]['run_server_info_status']; ?>:</span> <font color="green">online</font>';
		console.log("json.version: ", version);
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
      //console.log("Info: ", info);
      document.getElementById('server_info').innerHTML = info;
      document.getElementById('server_info').classList.remove('d-none');

      //var short_info = "&nbsp; <?php echo $lang[$currentLang]['run_server_info_version']; ?>: <i>" + version + "</i>";
      var short_info = "<i>" + version + "</i>";
      //console.log("Short info: ", short_info);
      document.getElementById('server_short_info').innerHTML = short_info;
      document.getElementById('server_short_info').classList.remove('d-none');
      
 
    }});
  }


  function deleteInputText() {
    var t=document.getElementById('input');
    t.value='';
    t.style.color = '#333333'; // Změní barvu na tmavou při psaní (měl by zajistit event spuštěný focusem, ale to se nedělo)
    t.focus();
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
    if (output_display_originals) { // zobrazím původní výsledný text (vč. originálů)
      formatted_output = output_file_content;
    } else { // vyhodím z výsledného textu originály
      formatted_output = removeOriginals(output_file_content);
    }
    if (output_display_colours) { // zobrazím původní výsledný text (vč. barevného zvýraznění)
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
      var toggleColoursButton = document.getElementById("button_toggle_output_colours");

      if (txtRadio.checked) {
        // Zneaktivní checkbox při výběru TXT radio tlačítka
        //console.log("handleOutputFormatChange - disabling the checkbox");
        toggleColoursButton.disabled = true;
      } else if (htmlRadio.checked) {
        // Zaktivní checkbox při výběru HTML radio tlačítka
        //console.log("handleOutputFormatChange - enabling the checkbox");
        toggleColoursButton.disabled = false;
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

function toggleOutputOriginals() {
    // Přepnutí hodnoty globální proměnné
    output_display_originals = output_display_originals === 0 ? 1 : 0;

    // Získání elementů
    const buttonText = document.getElementById('text_toggle_output_originals');
    const button = document.getElementById('button_toggle_output_originals');

    // Nastavení přeškrtnutí a tooltipu
    if (output_display_originals === 0) {
        buttonText.style.textDecoration = 'none';
        button.title = '<?php echo $lang[$currentLang]['run_output_show_originals_tooltip']; ?>';
    } else {
        buttonText.style.textDecoration = 'line-through';
        buttonText.style.textDecorationThickness = '1px';
        button.title = '<?php echo $lang[$currentLang]['run_output_do_not_show_originals_tooltip']; ?>';
    }
    displayFormattedOutput();
}

function toggleOutputColours() {
    // Přepnutí hodnoty globální proměnné
    output_display_colours = output_display_colours === 0 ? 1 : 0;

    // Získání elementů
    const buttonText = document.getElementById('text_toggle_output_colours');
    const button = document.getElementById('button_toggle_output_colours');

    // Nastavení přeškrtnutí a tooltipu
    if (output_display_colours === 0) {
        buttonText.style.textDecoration = 'none';
        button.title = '<?php echo $lang[$currentLang]['run_output_show_colours_tooltip']; ?>';
    } else {
        buttonText.style.textDecoration = 'line-through';
        buttonText.style.textDecorationThickness = '1px';
        button.title = '<?php echo $lang[$currentLang]['run_output_do_not_show_colours_tooltip']; ?>';
    }
    displayFormattedOutput();
}


function displayShortSelectedOptions() {
    // Získání vybraného formátu vstupu
    const inputOptions = document.getElementsByName('option_input');
    let selectedInput = '';
    let selectedInputLabel = '';
    for (const option of inputOptions) {
        if (option.checked) {
            selectedInput = option.id;
            selectedInputLabel = document.querySelector(`label[for="${selectedInput}"]`).textContent.replace(/\(.*?\)/g, '').trim();
            break;
        }
    }

    // Získání vybraného formátu výstupu
    const outputOptions = document.getElementsByName('option_output');
    let selectedOutput = '';
    let selectedOutputLabel = '';
    for (const option of outputOptions) {
        if (option.checked) {
            selectedOutput = option.id;
            selectedOutputLabel = document.querySelector(`label[for="${selectedOutput}"]`).textContent.replace(/\(.*?\)/g, '').trim();
            break;
        }
    }

    // Získání stavu checkboxů pro randomize a classes
    const randomizeCheckbox = document.getElementById('option_randomize');
    const classesCheckbox = document.getElementById('option_classes');
    let randomizeLabel = '';
    let classesLabel = '';
    if (randomizeCheckbox.checked) {
        randomizeLabel = document.querySelector(`label[for="option_randomize"]`).textContent.trim();
    }
    if (classesCheckbox.checked) {
        classesLabel = document.querySelector(`label[for="option_classes"]`).textContent.trim();
    }

    // Získání názvů popisků
    const inputLabel = "<span class=\"fw-bold ms-1 me-2\"><?php echo $lang[$currentLang]['run_options_input_label']; ?>:</span>";
    const outputLabel = "<span class=\"fw-bold ms-3 me-2\"><?php echo $lang[$currentLang]['run_options_output_label']; ?>:</span>";
    const optionsLabel = "<span class=\"fw-bold ms-3 me-2\"><?php echo $lang[$currentLang]['run_options_options_label']; ?>:</span>";

    // Sestavení pole pro volby (randomize a classes), pokud jsou zaškrtnuty
    const selectedOptions = [];
    if (randomizeLabel) selectedOptions.push(randomizeLabel);
    if (classesLabel) selectedOptions.push(classesLabel);
    const optionsText = selectedOptions.length > 0 ? `${optionsLabel} ${selectedOptions.join(', ')}` : '';

    // Sestavení výsledného řetězce
    const finalString = `${inputLabel} ${selectedInputLabel} ${outputLabel} ${selectedOutputLabel}${optionsText ? ' ' + optionsText : ''}`;
    document.getElementById('options_short_info').innerHTML = finalString;

    // Collapse the options panel after an option has been changed
    const aboutContent = document.getElementById('aboutContent');
    const collapse = new bootstrap.Collapse(aboutContent, { toggle: false });
    collapse.hide();
}

--></script>


<!--div class="container-fluid border rounded px-0 mt-1" style="height: 85vh;"-->
<div class="container-fluid border rounded px-0 mt-1">

    <!-- ================= OPTIONS ================ -->

    <!-- ================= Options card ================ -->
    <div class="card">
      <div class="card-header p-0" role="tab" id="aboutHeading">
        <button class="btn btn-link collapsed py-2 px-3 w-100 text-start d-block text-decoration-none" type="button" data-bs-toggle="collapse" data-bs-target="#aboutContent" aria-expanded="false" aria-controls="aboutContent">
          <i class="fa-solid fa-caret-down"></i> <span id="options_short_info"></span>
        </button>
      </div>
      <!-- ================= Options panel ================ -->
      <div id="aboutContent" class="collapse m-1 pb-2" style="padding-top: 16px" role="tabpanel" aria-labelledby="aboutHeading">


      <div class="row mb-0" style="font-size: 0.9rem;">
        <label class="col-2 col-form-label fw-bold text-end pe-3 py-0" style="line-height: 1.2;"><?php echo $lang[$currentLang]['run_options_input_label']; ?>:</label>
        <div class="col-10 d-flex gap-3 align-items-center">
          <div class="form-check py-0">
            <input class="form-check-input" name="option_input" type="radio" value="txt" id="option_input_plaintext" onchange="displayShortSelectedOptions();" checked>
            <label class="form-check-label" for="option_input_plaintext" title="<?php echo $lang[$currentLang]['run_options_input_plain_popup']; ?>">
              <?php echo $lang[$currentLang]['run_options_input_plain']; ?>
            </label>
          </div>
          <div class="form-check py-0">
            <input class="form-check-input" name="option_input" type="radio" value="presegmented" id="option_input_presegmented" onchange="displayShortSelectedOptions();">
            <label class="form-check-label" for="option_input_presegmented" title="<?php echo $lang[$currentLang]['run_options_input_presegmented_popup']; ?>">
              <?php echo $lang[$currentLang]['run_options_input_presegmented']; ?> 
              (<a href="http://ufal.mff.cuni.cz/maskit/users-manual#run_maskit_input" target="_blank"><?php echo $lang[$currentLang]['run_options_input_presegmented_note']; ?></a>)
            </label>
          </div>
        </div>
      </div>
      <div class="row mb-0" style="font-size: 0.9rem;">
        <label class="col-2 col-form-label fw-bold text-end pe-3 py-0" style="line-height: 1.2;"><?php echo $lang[$currentLang]['run_options_output_label']; ?>:</label>
        <div class="col-10 d-flex gap-3 align-items-center">
          <div class="form-check py-0">
            <input class="form-check-input" name="option_output" type="radio" value="txt" id="option_output_txt" onchange="handleOutputFormatChange(); displayShortSelectedOptions();">
            <label class="form-check-label" for="option_output_txt" title="<?php echo $lang[$currentLang]['run_options_output_txt_popup']; ?>">
              <?php echo $lang[$currentLang]['run_options_output_txt']; ?>
              (<a href="http://ufal.mff.cuni.cz/maskit/users-manual#run_maskit_output" target="_blank"><?php echo $lang[$currentLang]['run_options_output_txt_note']; ?></a>)
            </label>
          </div>
          <div class="form-check py-0">
            <input class="form-check-input" name="option_output" type="radio" value="html" id="option_output_html" checked onchange="handleOutputFormatChange(); displayShortSelectedOptions();">
            <label class="form-check-label" for="option_output_html" title="<?php echo $lang[$currentLang]['run_options_output_html_popup']; ?>">
              <?php echo $lang[$currentLang]['run_options_output_html']; ?>
              (<a href="http://ufal.mff.cuni.cz/maskit/users-manual#run_maskit_output" target="_blank"><?php echo $lang[$currentLang]['run_options_output_html_note']; ?></a>)
            </label>
          </div>
        </div>
      </div>
      <div class="row mb-0" style="font-size: 0.9rem;">
        <label class="col-2 col-form-label fw-bold text-end pe-3 py-0" style="line-height: 1.2;"><?php echo $lang[$currentLang]['run_options_options_label']; ?>:</label>
        <div class="col-10 d-flex gap-3 align-items-center">
          <div class="form-check py-0">
            <input class="form-check-input" id="option_randomize" name="option_randomize" type="checkbox" checked onchange="handleRandomizeChanged(); displayShortSelectedOptions();">
            <label class="form-check-label" for="option_randomize" title="<?php echo $lang[$currentLang]['run_options_options_randomize_popup']; ?>">
              <?php echo $lang[$currentLang]['run_options_options_randomize']; ?>
            </label>
          </div>
          <div class="form-check py-0">
            <input class="form-check-input" id="option_classes" name="option_classes" type="checkbox" onchange="handleClassesChanged(); displayShortSelectedOptions();">
            <label class="form-check-label" for="option_classes" title="<?php echo $lang[$currentLang]['run_options_options_classes_popup']; ?>">
              <?php echo $lang[$currentLang]['run_options_options_classes']; ?>
            </label>
          </div>
        </div>
      </div>
    </div>
    
    <!-- ================= INPUT FIELD ================ -->

    <!-- input field tab -->
    <ul class="nav nav-tabs nav-tabs-green nav-tabs-custom nav-fill">
      <li class="nav-item" id="input_text_header">
        <a class="nav-link active d-flex align-items-center" href="#input_text" data-bs-toggle="tab">
          <span class="fa fa-font me-2"></span>
          <span><?php echo $lang[$currentLang]['run_input_text']; ?></span>
          <div class="ms-auto d-flex gap-2">
            <button class="btn btn-sm btn-primary btn-maskit-colors btn-maskit-small" onclick="deleteInputText();">
              <span class="fas fa-trash"></span>
            </button>
          </div>
        </a>
      </li>
    </ul>

    <!-- input field text -->
    <div class="tab-content" id="input_tabs" style="border-right: 1px solid #ddd; border-left: 1px solid #ddd; border-bottom: 1px solid #ddd; border-bottom-right-radius: 5px; border-bottom-left-radius: 5px; padding: 15px;">
      <div class="tab-pane active" id="input_text">
        <textarea id="input" class="form-control" rows="8" cols="80"><?php echo $lang['cs']['run_input_text_default_text']; ?></textarea>
      </div>
    </div>

    <!-- main submit button -->

    <button id="submit" class="py-2 nav-link btn btn-primary btn-maskit-colors d-flex align-items-center justify-content-center w-100 text-white" type="submit" onclick="doSubmit()">
        <span class="fa fa-arrow-down me-2"></span>
        <span><?php echo $lang[$currentLang]['run_process_input']; ?></span>
        <span class="fa fa-arrow-down ms-2"></span>
      </button>


    <!-- ================= OUTPUT FIELDS ================ -->
    
    <ul class="nav nav-tabs nav-tabs-green nav-tabs-custom nav-fill">

      <!-- output text tab -->
      <li class="nav-item" id="output_text_header">
        <a class="nav-link active d-flex align-items-center" href="#output_formatted" data-bs-toggle="tab">
          <span class="fa fa-font me-2"></span>
          <span><?php echo $lang[$currentLang]['run_output_text']; ?></span>
          <div class="ms-auto d-flex gap-2">
            <button id="button_toggle_output_originals" class="btn btn-primary btn-sm btn-maskit-colors btn-maskit-small" onclick="toggleOutputOriginals();" title="<?php echo $lang[$currentLang]['run_output_do_not_show_originals_tooltip']; ?>">
              <span id="text_toggle_output_originals" style="text-decoration: line-through; text-decoration-thickness: 1px"><?php echo $lang[$currentLang]['run_output_show_originals']; ?></span>
            </button>
            <button id="button_toggle_output_colours" class="btn btn-primary btn-sm btn-maskit-colors btn-maskit-small" onclick="toggleOutputColours();" title="<?php echo $lang[$currentLang]['run_output_do_not_show_colours_tooltip']; ?>">
              <span id="text_toggle_output_colours" style="text-decoration: line-through; text-decoration-thickness: 1px"><?php echo $lang[$currentLang]['run_output_show_colours']; ?></span>
            </button>

            <button class="btn btn-primary btn-sm btn-maskit-colors btn-maskit-small" onclick="saveOutput(); event.stopPropagation();">
              <span class="fa fa-download"></span>
            </button>
          </div>
        </a>
      </li>

      <!-- output stats tab -->
      <li class="nav-item" id="output_stats_header">
        <a class="nav-link d-flex align-items-center" href="#output_stats" data-bs-toggle="tab">
          <span class="fa fa-font me-2"></span>
          <span><?php echo $lang[$currentLang]['run_output_statistics']; ?></span>
          <div class="ms-auto d-flex gap-2">
            <button class="btn btn-primary btn-sm btn-maskit-colors btn-maskit-small" onclick="saveStats(); event.stopPropagation();">
              <span class="fa fa-download"></span>
            </button>
          </div>
        </a>
      </li>

    </ul>

    <!-- output panels -->
    <div class="tab-content" id="output_tabs" style="border-right: 1px solid #ddd; border-left: 1px solid #ddd; border-bottom: 1px solid #ddd; border-bottom-right-radius: 5px; border-bottom-left-radius: 5px; padding: 15px;">
      <div class="tab-pane active" id="output_formatted" style="min-height: 300px; max-height: 85vh; overflow-y: auto;"></div>
      <div class="tab-pane" id="output_stats" style="min-height: 300px; max-height: 85vh; overflow-y: auto;"></div>
    </div>

  </div>
</div>

