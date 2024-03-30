// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

function HTTPTransport() {
  "use strict";

  // TODO(adg): support stderr

  function playback(output, events) {
    var timeout;
    output({ Kind: "start" });
    function next() {
      if (!events || events.length === 0) {
        output({ Kind: "end" });
        return;
      }
      var e = events.shift();
      if (e.Delay === 0) {
        output({ Kind: "stdout", Body: e.Message });
        next();
        return;
      }
      timeout = setTimeout(function () {
        output({ Kind: "stdout", Body: e.Message });
        next();
      }, e.Delay / 1000000);
    }
    next();
    return {
      Stop: function () {
        clearTimeout(timeout);
      },
    };
  }

  function error(output, msg) {
    output({ Kind: "start" });
    output({ Kind: "stderr", Body: msg });
    output({ Kind: "end" });
  }

  var seq = 0;
  return {
    Run: function (body, output, options) {
      seq++;
      var cur = seq;
      var playing;
      $.ajax("/compile", {
        type: "POST",
        data: { version: 2, body: body },
        dataType: "json",
        success: function (data) {
          if (seq != cur) return;
          if (!data) return;
          if (playing != null) playing.Stop();
          if (data.Errors) {
            error(output, data.Errors);
            return;
          }
          playing = playback(output, data.Events);
        },
        error: function () {
          error(output, "Error communicating with remote server.");
        },
      });
      return {
        Kill: function () {
          if (playing != null) playing.Stop();
          output({ Kind: "end", Body: "killed" });
        },
      };
    },
  };
}

function SocketTransport() {
  "use strict";

  var id = 0;
  var outputs = {};
  var started = {};
  var websocket = new WebSocket("ws://" + window.location.host + "/socket");

  websocket.onclose = function () {
    console.log("websocket connection closed");
  };

  websocket.onmessage = function (e) {
    var m = JSON.parse(e.data);
    var output = outputs[m.Id];
    if (output === null) return;
    if (!started[m.Id]) {
      output({ Kind: "start" });
      started[m.Id] = true;
    }
    output({ Kind: m.Kind, Body: m.Body });
  };

  function send(m) {
    websocket.send(JSON.stringify(m));
  }

  return {
    Run: function (body, output, options) {
      var thisID = id + "";
      id++;
      outputs[thisID] = output;
      send({ Id: thisID, Kind: "run", Body: body, Options: options });
      return {
        Kill: function () {
          send({ Id: thisID, Kind: "kill" });
        },
      };
    },
  };
}

function PlaygroundOutput(el) {
  "use strict";

  return function (write) {
    if (write.Kind == "start") {
      el.innerHTML = "";
      return;
    }

    var cl = "system";
    if (write.Kind == "stdout" || write.Kind == "stderr") cl = write.Kind;

    var m = write.Body;
    if (write.Kind == "end") m = "\nProgram exited" + (m ? ": " + m : ".");

    if (m.indexOf("IMAGE:") === 0) {
      // TODO(adg): buffer all writes before creating image
      var url = "data:image/png;base64," + m.substr(6);
      var img = document.createElement("img");
      img.src = url;
      el.appendChild(img);
      return;
    }

    // ^L clears the screen.
    var s = m.split("\x0c");
    if (s.length > 1) {
      el.innerHTML = "";
      m = s.pop();
    }

    m = m.replace(/&/g, "&amp;");
    m = m.replace(/</g, "&lt;");
    m = m.replace(/>/g, "&gt;");

    var needScroll = el.scrollTop + el.offsetHeight == el.scrollHeight;

    var span = document.createElement("span");
    span.className = cl;
    span.innerHTML = m;
    el.appendChild(span);

    if (needScroll) el.scrollTop = el.scrollHeight - el.offsetHeight;
  };
}

(function () {
  function lineHighlight(error) {
    if (!code || !error) {
      return;
    }
    var errorRe = /[a-z0-9]+\.zig:([0-9]+):/g;
    var result;
    while ((result = errorRe.exec(error)) !== null) {
      var line = result[1] * 1 - 1;
      code.addLineClass(line, null, "errLine");
    }
    code.on("change", function () {
      for (var i = 0; i < code.lineCount(); i++) {
        code.removeLineClass(i, null, "errLine");
      }
    });
  }
  function highlightOutput(wrappedOutput) {
    return function (write) {
      if (write.Body) lineHighlight(write.Body);
      wrappedOutput(write);
    };
  }

  // opts is an object with these keys
  //  codeEl - code editor element
  //  outputEl - program output element
  //  runEl - run button element
  //  fmtEl - fmt button element (optional)
  //  fmtImportEl - fmt "imports" checkbox element (optional)
  //  shareEl - share button element (optional)
  //  shareURLEl - share URL text input element (optional)
  //  shareRedirect - base URL to redirect to on share (optional)
  //  toysEl - toys select element (optional)
  //  enableHistory - enable using HTML5 history API (optional)
  //  transport - playground transport to use (default is HTTPTransport)
  function playground(opts) {
    var transport = opts["transport"] || new HTTPTransport();
    var running;

    function autoindent(el) {
      var curpos = el.selectionStart;
      var tabs = 0;
      while (curpos > 0) {
        curpos--;
        if (el.value[curpos] == "\t") {
          tabs++;
        } else if (tabs > 0 || el.value[curpos] == "\n") {
          break;
        }
      }
    }

    function keyHandler(e) {
      if (e.keyCode == 9 && !e.ctrlKey) {
        // tab (but not ctrl-tab)
        //insertTabs(1);
        e.preventDefault();
        return false;
      }
      if (e.keyCode == 13) {
        // enter
        if (e.shiftKey) {
          // +shift
          run();
          e.preventDefault();
          return false;
        }
        if (e.ctrlKey) {
          // +control
          fmt();
          e.preventDefault();
        } else {
          autoindent(e.target);
        }
      }
      return true;
    }
    document.onkeydown = keyHandler;
    var outdiv = $(opts.outputEl).empty();
    var output = $("<pre/>").appendTo(outdiv);

    function body() {
      return code.getValue();
    }
    function setBody(text) {
      code.setValue(text);
    }
    function origin(href) {
      return ("" + href).split("/").slice(0, 3).join("/");
    }

    var pushedEmpty = window.location.pathname == "/";
    function inputChanged() {
      if (pushedEmpty) {
        return;
      }
      pushedEmpty = true;
      $(opts.shareURLEl).hide();
      window.history.pushState(null, "", "/");
    }
    function popState(e) {
      if (e === null) {
        return;
      }
      if (e && e.state && e.state.code) {
        setBody(e.state.code);
      }
    }
    var rewriteHistory = false;
    if (
      window.history &&
      window.history.pushState &&
      window.addEventListener &&
      opts.enableHistory
    ) {
      rewriteHistory = true;
      window.addEventListener("input", inputChanged);
      window.addEventListener("popstate", popState);
    }

    function setError(error) {
      if (running) running.Kill();
      lineHighlight(error);
      output.empty().addClass("error").text(error);
    }
    function loading() {
      if (running) running.Kill();
      output.removeClass("error").text("Waiting for remote server...");
    }
    function run() {
      loading();
      running = transport.Run(
        body(),
        highlightOutput(PlaygroundOutput(output[0])),
      );
    }

    function fmt() {
      loading();
      var data = { body: body() };
      if ($(opts.fmtImportEl).is(":checked")) {
        data["imports"] = "true";
      }
      $.ajax("/fmt", {
        data: data,
        type: "POST",
        dataType: "json",
        success: function (data) {
          if (data.Error) {
            setError(data.Error);
          } else {
            setBody(data.Body);
            setError("");
          }
        },
      });
    }

    $(opts.runEl).click(run);
    $(opts.fmtEl).click(fmt);

    if (
      opts.shareEl !== null &&
      (opts.shareURLEl !== null || opts.shareRedirect !== null)
    ) {
      var shareURL;
      if (opts.shareURLEl) {
        shareURL = $(opts.shareURLEl).hide();
      }
      var sharing = false;
      $(opts.shareEl).click(function () {
        if (sharing) return;
        sharing = true;
        var sharingData = body();
        $.ajax("/share", {
          processData: false,
          data: sharingData,
          type: "POST",
          complete: function (xhr) {
            sharing = false;
            if (xhr.status != 200) {
              alert("Server error; try again.");
              return;
            }
            if (opts.shareRedirect) {
              window.location = opts.shareRedirect + xhr.responseText;
            }
            if (shareURL) {
              var path = "/p/" + xhr.responseText;
              var url = origin(window.location) + path;
              shareURL.show().val(url).focus().select();

              if (rewriteHistory) {
                var historyData = { code: sharingData };
                window.history.pushState(historyData, "", path);
                pushedEmpty = false;
              }
            }
          },
        });
      });
    }

    if (opts.toysEl !== null) {
      $(opts.toysEl).bind("change", function () {
        var toy = $(this).val();
        $.ajax("/doc/play/" + toy, {
          processData: false,
          type: "GET",
          complete: function (xhr) {
            if (xhr.status != 200) {
              alert("Server error; try again.");
              return;
            }
            setBody(xhr.responseText);
          },
        });
      });
    }
  }

  window.playground = playground;
})();
