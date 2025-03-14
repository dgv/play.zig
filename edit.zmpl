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
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.18/codemirror.min.js" integrity="sha512-6cPYokihlrofMNApz7OXVQNObWjLiKGIBBb7+UB+AuMiRCLKmFKgrwms21sHq3bdFFZWpfHYRJBJvMFMPj1S9g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.18/codemirror.min.css" integrity="sha512-uf06llspW44/LZpHzHT6qBOIVODjWtv4MxCricRxkzvopAlSWnTf6hpZTFxuuZcuNE9CBQhqE0Seu1CoRk84nQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.18/theme/mbo.min.css" integrity="sha512-od4iTUzGO7D57XePY29GbKmPNZTDtZcSSTFOLg9Bse/uA8dznrj2wP+GgB72zmoOj6M/M1rXBip5bT8jvbgMlg==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.18/addon/search/searchcursor.min.js" integrity="sha512-+ZfZDC9gi1y9Xoxi9UUsSp+5k+AcFE0TRNjI0pfaAHQ7VZTaaoEpBZp9q9OvHdSomOze/7s5w27rcsYpT6xU6g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.18/addon/edit/matchbrackets.min.js" integrity="sha512-GSYCbN/le5gNmfAWVEjg1tKnOH7ilK6xCLgA7c48IReoIR2g2vldxTM6kZlN6o3VtWIe6fHu/qhwxIt11J8EBA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="/static/codemirror/mode/zig/zig.js"></script>
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
        <a href="/"><span id="header-image"></span></a>
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
