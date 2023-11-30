<?php $main_page=basename(__FILE__); require('header.php') ?>

<div class="dropdown pull-right" style='margin-left: 10px; margin-bottom: 10px'>
  <button class="btn btn-default dropdown-toggle" type="button" id="tocDropdown" data-toggle="dropdown"><span class="fa fa-bars"></span> Table of Contents <span class="caret"></span></button>
  <ul class="dropdown-menu dropdown-menu-right" aria-labelledby="tocDropdown">
    <li><a href="#api_reference">API Reference</a></li>
    <li><a href="#process"><span class="fa fa-caret-right"></span> <code>process</code></a></li>
    <li class="divider"></li>
    <li><a href="#using_curl">Accessing API using Curl</a></li>
  </ul>
</div>

<p>MasKIT REST API web service is available on
<code>http(s)://quest.ms.mff.cuni.cz/maskit/api/</code>.</p>

<?php require('licence.html') ?>

<h2 id="api_reference">API Reference</h2>

<p>TODO</p>

<p>The SouDeC REST API can be accessed <a href="run.php">directly</a> or via web
programming tools that support standard HTTP request methods and JSON for output
handling.</p>

<table class='table table-striped table-bordered'>
<tr>
    <th>Service Request</th>
    <th>Description</th>
    <th>HTTP Method</th>
</tr>
<tr>
    <td><a href="#detect">detect</a></td>
    <td><a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec" target="_blank">detect and classify sources</a></td>
    <td>GET/POST</td>
</tr>
</table>


<h3>Method <a id='detect'>detect</a></h3>

<p>Process the given data as described in <a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec" target="_blank">the User's Manual</a>.</p>

<table class='table table-striped table-bordered'>
<tr><th>Parameter</th><th>Mandatory</th><th>Data type</th><th>Description</th></tr>
<tr><td>text</td><td>yes</td><td>string</td><td>Input text in <b>UTF-8</b>.</td></tr>
<tr><td>input</td><td>no</td><td>string</td><td>Input format; possible values: <code>txt</code> (default), <code>presegmented</code>, see <a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec_input" target="_blank">input format</a> for details.</td></tr>
<tr><td>output</td><td>no</td><td>string</td><td>Output format; possible values: <code>txt</code> (default), <code>html</code>, <code>conllu</code>, see <a href="http://ufal.mff.cuni.cz/soudec/users-manual#run_soudec_output" target="_blank">output format</a> for details.</td></tr>
</table>

<p>
The response is in <a href="http://en.wikipedia.org/wiki/JSON" target="_blank">JSON</a> format of the
following structure:</p>

<pre class="prettyprint lang-json">
{
 "result": "processed_output"
 "stats": "statistics"
}
</pre>

The <code>processed_output</code> is the output of SouDeC in the requested output format
<br/>and <code>statistics</code> is an HTML overview of the detected sources and their classes.


<h2 style="margin-top: 20px">Browser Example</h2>
<table style='width: 100%'>
 <tr><td style='vertical-align: middle'><pre style='margin-bottom: 0; white-space: pre-wrap' class="prettyprint lang-html">http://quest.ms.mff.cuni.cz/soudec/api/detect?input=txt&amp;output=txt&amp;text=Paní Marie Nováková z Myslíkovy ulice č. 25 dostala dopis od firmy ČEZ..</pre></td>
     <td style='vertical-align: middle; width: 6em'><button style='width: 100%' type="button" class="btn btn-success btn-xs" onclick="window.open('http://quest.ms.mff.cuni.cz/soudec/api/detect?input=txt&amp;output=txt&amp;text=Paní Marie Nováková z Myslíkovy ulice č. 25 dostala dopis od firmy ČEZ.')">try&nbsp;this</button></td></tr>
</table>

<hr />

<h2 id="using_curl">Accessing API using Curl</h2>

The described API can be comfortably used by <code>curl</code>. Several examples follow:

<h3>Passing Input on Command Line (if UTF-8 locale is being used)</h3>
<pre style="white-space: pre-wrap" class="prettyprint lang-sh">curl --data 'input=txt&amp;output=txt&amp;text=SouDec tvrdí, že tohle je citace.' http://quest.ms.mff.cuni.cz/soudec/api/detect</pre>

<h3>Using Files as Input (files must be in UTF-8 encoding)</h3>
<pre style="white-space: pre-wrap" class="prettyprint lang-sh">curl --data-urlencode 'input=txt' --data-urlencode 'output=html' --data-urlencode 'text@input_file.txt' http://quest.ms.mff.cuni.cz/soudec/api/detect</pre>

<h3>Converting JSON Result to Plain Text</h3>
<pre style="white-space: pre-wrap" class="prettyprint lang-sh">curl --data 'input=txt&amp;output=txt&amp;text=SouDec tvrdí, že tohle je citace.' http://quest.ms.mff.cuni.cz/soudec/api/detect | PYTHONIOENCODING=utf-8 python -c "import sys,json; sys.stdout.write(json.load(sys.stdin)['result'])"</pre>

<?php require('footer.php') ?>
