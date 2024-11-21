<!doctype html>
<html>

<head>
    <meta charset="utf-8">
    <title>Zig Playground</title>
    <link rel="stylesheet" href="/static/style.css" />
    <script
      src="https://code.jquery.com/jquery-2.2.4.min.js"
      integrity="sha256-BbhdlvQf/xTY9gja0Dq3HiwQF8LaCRTXxZKRutelT44="
      crossorigin="anonymous"></script>
    <script src="/static/playground.js"></script>
    <link rel="icon" href=/static/favicon.ico>
    <link rel="shortcut icon" href=/static/favicon.svg>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/3.24.0/codemirror.min.js" integrity="sha512-BmHROXH6Q9Dd/pW9Xbjthhz2fgLZ79RtjpqMfWM2ZXexZXJky3t3xTMtBkUY3ifhZrPozE6LwOyHVlfceBpzyw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/3.24.0/codemirror.min.css" integrity="sha512-HSTUwV7IgV9k3+iHfqu1Z8p4CI5Z+0P4ogvCO0X54FLbfRGPWnGDMqxQMSstyYDOw+J88h+Uw45/gb9BO6Tp4g==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <script src="/static/codemirror/mode/zig/zig.js"></script>
    <link rel="stylesheet" href="/static/codemirror/theme/mbo.css" />
    <script src="/static/codemirror/addon/search/searchcursor.js"></script>
    <script src="/static/codemirror/addon/edit/matchbrackets.js"></script>
    <link rel="stylesheet" href="/static/codemirror/addon/dialog/dialog.css" />
    <script>
        $(document).ready(function () {
            code = CodeMirror.fromTextArea(document.getElementById("code"), {
                theme: "mbo",
                matchBrackets: true,
                indentUnit: 4,
                tabSize: 4,
                indentWithTabs: false,
                lineWrapping: true,
                mode: "text/x-zig",
                lineNumbers: true,
                showCursorWhenSelecting: true,
            });
            $code = $(code.getWrapperElement()).attr("id", "code");
            code.refresh();
            playground({
                outputEl: "#output",
                runEl: "#run",
                fmtEl: "#fmt",
                fmtImportEl: "#imports",
                shareEl: "#share",
                shareURLEl: "#shareURL",
                enableHistory: true,
            });

            $(function(){
              // bind change event to select
              $('#ziglings').on('change', function () {
                var url = '/?zigling='+$(this).val(); // get selected value
                  if (url) { // require a URL
                      window.location = url; // redirect
                  }
                  return false;
              });
            });
            if (window.trackEvent) {
                $("#run").click(function () {
                    window.trackEvent("playground", "click", "run-button");
                });
                $("#share").click(function () {
                    window.trackEvent("playground", "click", "share-button");
                });
            }
        });

        function createCookie(name, value) {
            document.cookie = name + "=" + value + "; path=/";
        }

        function readCookie(name) {
            var nameEQ = name + "=";
            var ca = document.cookie.split(";");
            for (var i = 0; i < ca.length; i++) {
                var c = ca[i];
                while (c.charAt(0) == " ") c = c.substring(1, c.length);
                if (c.indexOf(nameEQ) == 0)
                    return c.substring(nameEQ.length, c.length);
            }
            return null;
        }
    </script>
</head>

<body itemscope itemtype="http://schema.org/CreativeWork">
    <div id="banner">
        <div id="head" itemprop="name"><a href="/">Zig Playground</a></div>
        <div id="controls">
            <input type="button" value="Run" id="run" />
            <input type="button" value="Format" id="fmt" />
            <input type="button" value="Share" id="share" />
            <input type="text" id="shareURL" />
        </div>
        <div id="ziglingsList">
            <a href="https://codeberg.org/ziglings/exercises" target="_blank">Ziglings</a>: <select id="ziglings" aria-label="Ziglings files">
                <option style="display:none"></option>
                {{.ziglings}}
                </select>
      </div>
    </div>
    <div id="wrap">
        <textarea id="code" name="code" spellcheck="false">{{.snippet}}</textarea>
    </div>
    <div id="output"></div>
    <a href="https://github.com/dgv/play.zig" target="_blank"><img id="ziggy" class="absolute right-2 bottom-2 w-20 max-w-sm z-10" style="transform: scaleX(-1)" src="/static/ziggy.svg"></a>
</body>

</html>
