<?php
// Spuštění session pro uchovávání jazyka mezi požadavky
session_start();

// Změna jazyka přes GET parametr
if (isset($_GET['lang']) && $_GET['lang'] !== $_SESSION['lang']) {
    $_SESSION['lang'] = $_GET['lang'];

    // Získání aktuální URL bez lang parametru
    $baseUrl = '/maskit';
    $currentUrlWithoutLang = preg_replace('/(\?|&)lang=[^&]*/', '', $_SERVER['REQUEST_URI']);
    // Odstranění tab parametru pro čisté přesměrování, pokud je potřeba
    $currentUrlWithoutLang = preg_replace('/(\?|&)tab=[^&]*/', '', $currentUrlWithoutLang);

    // Přesměrování na URL bez lang parametru
    header("Location: " . $baseUrl . $currentUrlWithoutLang);
    exit();

    header("Location: " . $redirectUrl);
    exit();
}

// Nastavení defaultního jazyka, pokud není nastavený
if (!isset($_SESSION['lang'])) {
    $_SESSION['lang'] = 'cs'; // Defaultní jazyk je český
}

// Zpracování parametru tab pro výběr aktivní záložky
$validTabs = ['info', 'run', 'api'];
$activeTab = isset($_GET['tab']) && in_array($_GET['tab'], $validTabs) ? $_GET['tab'] : 'run';

// Načtení jazykového souboru
require 'lang.php';

// Uložení aktuálního jazyka do proměnné pro snadnější použití
$currentLang = $_SESSION['lang'];
?>

<!DOCTYPE html>
<html style="scroll-behavior: auto;">
<head>
  <title>MasKIT</title>
  <meta charset="utf-8">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css">
  <link rel="stylesheet" href="css/lindat.css" type="text/css" />
  <link rel="stylesheet" href="css/maskit.css" type="text/css" />

  <script src="https://code.jquery.com/jquery-3.6.0.min.js" type="text/javascript"></script>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js" type="text/javascript"></script>
  <script src="https://unpkg.com/turndown/dist/turndown.js"></script>
</head>

<body id="lindat-services">
  <div class="lindat-common">
    <div class="container">
      <!-- Service title a menu vedle sebe -->
      <div class="d-flex align-items-end justify-content-between pt-lg-3">
        <!-- Nápis MasKIT -->
        <img src="img/logo.png" height="65px" style="padding-bottom: 5px; padding-top: 0px; padding-left: 2px">

        <!-- Server info (zobrazeno pouze pro Run tab) -->
        <div class="server-info-header mx-3" id="serverInfoHeader" style="display: none;">
          <div class="card-header" role="tab" id="serverInfoHeading" style="padding: 0.2rem 1rem; min-height: unset; background: none; border: none;">
            <button class="btn btn-link" type="button" data-bs-toggle="collapse" data-bs-target="#serverInfoContent" aria-expanded="false" aria-controls="serverInfoContent" style="padding: 0.2rem 0.5rem; font-size: 0.9rem; text-decoration: none;">
              <i class="fa-solid fa-caret-down" aria-hidden="true" style="font-size: 0.8rem;"></i> <?php echo $lang[$currentLang]['run_server_info_label']; ?>: <span id="server_short_info" class="d-none"></span>
            </button>
          </div>
        </div>

        <!-- Menu a vlaječka -->
        <div class="d-flex align-items-center">
          <!-- Menu -->
          <div class="menu-container position-relative">
            <ul class="nav nav-tabs nav-tabs-green mb-0" id="mainTabs">
              <li class="nav-item">
                <a class="nav-link <?php echo $activeTab === 'info' ? 'active' : ''; ?>" href="#info" data-bs-toggle="tab">
                  <span class="fa fa-info-circle"></span> <?php echo $lang[$currentLang]['menu_about']; ?>
                </a>
              </li>
              <li class="nav-item">
                <a class="nav-link <?php echo $activeTab === 'run' ? 'active' : ''; ?>" href="#run" data-bs-toggle="tab">
                  <span class="fa fa-cogs"></span> <?php echo $lang[$currentLang]['menu_run']; ?>
                </a>
              </li>
              <li class="nav-item">
                <a class="nav-link <?php echo $activeTab === 'api' ? 'active' : ''; ?>" href="#api" data-bs-toggle="tab">
                  <span class="fa fa-list"></span> <?php echo $lang[$currentLang]['menu_api']; ?>
                </a>
              </li>
            </ul>
          </div>

          <!-- Vlaječka odděleně -->
          <div class="ms-3">
            <?php
              if ($currentLang == 'cs') {
            ?>
                <a href="?lang=en&tab=<?php echo $activeTab; ?>" class="nav-link p-0">
                  <img src="img/flag_en.png" alt="English" style="height: 18px;">
                </a>
            <?php
              } else {
            ?>
                <a href="?lang=cs&tab=<?php echo $activeTab; ?>" class="nav-link p-0">
                  <img src="img/flag_cs.png" alt="čeština" style="height: 18px;">
                </a>
            <?php
              }
            ?>
          </div>
        </div>
      </div>

      <!-- Rozbalovací panel pro server info -->
      <div id="serverInfoContent" class="collapse mt-2" role="tabpanel" aria-labelledby="serverInfoHeading">
        <div class="card">
          <div class="card-body">
            <div id="server_info" class="d-none"></div>
            <?php
            if ($currentLang == 'cs') {
            ?>
                <div><?php require('licence_cs.html'); ?></div>
            <?php
            } else {
            ?>
                <div><?php require('licence_en.html'); ?></div>
            <?php
            }
            ?>
            <p><?php echo $lang[$currentLang]['run_server_info_word_limit']; ?></p>
            <div id="error" class="alert alert-danger d-none"></div>
          </div>
        </div>
      </div>

      <!-- JavaScript pro zobrazení server info a výběr záložky -->
      <script type="text/javascript">
        document.addEventListener('DOMContentLoaded', function() {
          const mainTabs = document.querySelector('#mainTabs');
          const serverInfoHeader = document.querySelector('#serverInfoHeader');
          const serverInfoContent = document.querySelector('#serverInfoContent');

          function updateServerInfoVisibility() {
            const runTab = document.querySelector('#run');
            if (runTab && runTab.classList.contains('active')) {
              serverInfoHeader.style.display = 'block';
            } else {
              serverInfoHeader.style.display = 'none';
              serverInfoContent.classList.remove('show');
            }
          }

          // Funkce pro výběr záložky přes JavaScript
          window.selectMainTab = function(tabId) {
            const tabLink = document.querySelector(`#mainTabs a[href="#${tabId}"]`);
            if (tabLink) {
              const bsTab = new bootstrap.Tab(tabLink);
              bsTab.show();
              updateServerInfoVisibility();
            }
          };

          // Spustit při načtení stránky
          updateServerInfoVisibility();

          // Aktualizace viditelnosti server info při přepnutí záložky
          mainTabs.addEventListener('shown.bs.tab', function() {
            updateServerInfoVisibility();
          });
        });
      </script>

      <!-- THREE MAIN PANELS: INFO, RUN, API -->
      <div class="tab-content mt-1">
        <!-- Info Tab -->
        <div class="tab-pane fade <?php echo $activeTab === 'info' ? 'show active' : ''; ?>" id="info">
          <?php require('info.php') ?>
        </div>
        <!-- Run Tab -->
        <div class="tab-pane fade <?php echo $activeTab === 'run' ? 'show active' : ''; ?>" id="run">
          <?php require('run.php') ?>
        </div>
        <!-- API Reference Tab -->
        <div class="tab-pane fade <?php echo $activeTab === 'api' ? 'show active' : ''; ?>" id="api">
          <?php require('api-reference.php') ?>
        </div>
      </div>

    </div>
  </div>

<!--?php require('branding/footer.htm')?-->

</body>
</html>
