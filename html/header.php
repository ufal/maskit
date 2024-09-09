
<?php
// Spuštění session pro uchovávání jazyka mezi požadavky
session_start();

// Změna jazyka přes GET parametr
if (isset($_GET['lang']) && $_GET['lang'] !== $_SESSION['lang']) {
    $_SESSION['lang'] = $_GET['lang'];
    
    // Získání aktuální URL bez lang parametru
    $baseUrl = '/maskit';
    $currentUrlWithoutLang = preg_replace('/(\?|&)lang=[^&]*/', '', $_SERVER['REQUEST_URI']);
    
    // Přesměrování na URL bez lang parametru
    header("Location: " . $baseUrl . $currentUrlWithoutLang);
    exit();
}

// Nastavení defaultního jazyka, pokud není nastavený
if (!isset($_SESSION['lang'])) {
    $_SESSION['lang'] = 'cs'; // Defaultní jazyk je český
}

// Načtení jazykového souboru
require 'lang.php';

// Uložení aktuálního jazyka do proměnné pro snadnější použití
$currentLang = $_SESSION['lang'];
?>


<!DOCTYPE html>
<html>
<head>
  <title>MasKIT</title>
  <meta charset="utf-8">

  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap-theme.min.css">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.4.0/css/font-awesome.min.css">

  <link rel="stylesheet" href="css/lindat.css" type="text/css" />
  <link rel="stylesheet" href="css/soudec.css" type="text/css" />

  <script src="https://code.jquery.com/jquery-1.11.3.min.js" type="text/javascript"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/js/bootstrap.min.js"></script>
  <script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js" type="text/javascript"></script>
</head>

<body id="lindat-services">
  <!--?php require('branding/header.htm')?-->
  <div class="lindat-common">
    <div class="container">
      <!--ul class="breadcrumb">
        <li><a href="//lindat.mff.cuni.cz/">LINDAT/CLARIN</a></li>
        <li><a href="//lindat.mff.cuni.cz/services/">Services</a></li>
        <li class="active">MasKIT</li>
      </ul-->

      <!-- Service title -->
      <h1 class="text-center">MasKIT</h1>

      <!-- menu -->
      <div class="menu-container" style="position: relative;"> <!-- kontejner pro umístění vlaječek vpravo -->
        <ul class="nav nav-tabs text-center" style="margin-bottom: 10px">
          <li <?php if ($main_page == 'info.php') echo ' class="active"'?>><a href="info.php"><span class="fa fa-info-circle"></span> <?php echo $lang[$currentLang]['menu_about']; ?></a></li>
          <li <?php if ($main_page == 'run.php') echo ' class="active"'?>><a href="run.php"><span class="fa fa-cogs"></span> <?php echo $lang[$currentLang]['menu_run']; ?></a></li>
          <li <?php if ($main_page == 'api-reference.php') echo ' class="active"'?>><a href="api-reference.php"><span class="fa fa-list"></span> <?php echo $lang[$currentLang]['menu_api']; ?></a></li>
          <!-- Přidání vlaječek pro změnu jazyka -->
          <?php
            if ($currentLang == 'cs') {
          ?>
              <li style="right: 10px; position: absolute; margin-left: 10px;"><a href="?lang=en"><img src="img/flag_en.png" alt="English" style="height: 18px;"></a></li>
          <?php
            } else { 
          ?>
              <li style="right: 10px; position: absolute; margin-left: 10px;"><a href="?lang=cs"><img src="img/flag_cs.png" alt="čeština" style="height: 18px;"></a></li>
          <?php
            }
          ?>
        </ul>
      </div>
