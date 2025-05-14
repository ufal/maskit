<div class="dropdown float-end" style="margin-left: 10px; margin-bottom: 10px;">
  <button class="btn btn-secondary dropdown-toggle" type="button" id="tocDropdown" data-bs-toggle="dropdown" aria-expanded="false">
    <span class="fa fa-bars"></span> Table of Contents 
  </button>
  <ul class="dropdown-menu dropdown-menu-end" aria-labelledby="tocDropdown">
    <li><a class="dropdown-item" href="#api_reference">API Reference</a></li>
    <li><a class="dropdown-item" href="#process"><span class="fa fa-caret-right"></span> <code>process</code></a></li>
    <li><hr class="dropdown-divider"></li>
    <li><a class="dropdown-item" href="#using_curl">Accessing API using Curl</a></li>
  </ul>
</div>

<p style="margin-left: 0px; margin-top: 8px; margin-bottom: 5px; margin-right: 5px"><?php echo $lang[$currentLang]['api_service_url']; ?>
<code>http(s)://quest.ms.mff.cuni.cz/maskit/api/</code>.</p>

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

          <?php
            if ($currentLang == 'cs') {
          ?>
    <div><?php require('api-reference_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div><?php require('api-reference_en.html') ?></div>
          <?php
            }
          ?>

