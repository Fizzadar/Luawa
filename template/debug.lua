local template = [[<!--
     __
    |  |  __ _______ __  _  _______
    |  | |  |  \__  \\ \/ \/ /\__  \
    |  |_|  |  // __ \\     /  / __ \_
    |____/____/(____  /\/\_/  (____  /
                    \/             \/

    debug
    site: luawa.com
    documentation: doc.luawa.com
-->

<div id="luawa_debug">
    <!--style-->
    <style type="text/css">
        /* button */
        a#luawa_debug_button {
            position: fixed;
            bottom: 0px;
            right: 10px;
            font-size: 20px;
            z-index: 99999;
            font-family: Arial;
            color: green;
            font-weight: bold;
            text-decoration: none;
            border: none;
            background: #F7F7F7;
            padding: 5px;
        }


        /* colors */
        .luawa_debug_red {
            color: red;
        }
        .luawa_debug_green {
            color: green;
        }
        .luawa_debug_orange {
            color: orange;
        }


        /* layout */
        a#luawa_img {
            position: fixed;
            top: 20px;
            left: 20px;
            width: 200px;
            z-index: 99;
            text-decoration: none;
            border: none;
            z-index: 99998;
            display: none;
        }
            a#luawa_img img {
                width: 100%;
            }

        div#luawa_debug {
            width: 100%;
            bottom: 0;
            left: 0;
            left: 0;
            top: 60%;
            overflow: hidden;
            background: #F7F7F7;
            border-top: 1px solid #D7D7D7;
            position: fixed;
            z-index: 99998;
            display: none;
            box-sizing: border-box;
            color: black;
            font-family: Arial;
            font-size: 14px;
            line-height: 24px;
        }


        div#luawa_debug table {
            width: 100%;
            border-collapse: collapse;
            border-spacing: 0;
        }
            div#luawa_debug table th {
                text-align: left;
                background: #D7D7D7;
                padding: 5px;
            }
            div#luawa_debug table td {
                padding: 5px;
            }
            div#luawa_debug table tr:hover {
                background: #F7F7F7;
            }

        #luawa_debug_resizer {
            cursor: pointer;
            text-align: center;
        }

        .luawa_block {
            position: absolute;
            overflow: hidden;
            margin: 0;
            padding-top: 30px;
            z-index: 97;
            height: 100%;
        }
        .luawa_twothird {
            width: 64%;
        }
        .luawa_third {
            width: 36%;
        }
            .luawa_block div {
                float: left;
                width: 100%;
                padding: 0px;
            }
            .luawa_block h4 {
                margin: 0;
                width: 100%;
                background: #FFF;
                padding: 5px;
                border-bottom: 1px solid #D7D7D7;
                border-top: 1px solid #D7D7D7;
                margin-top: -30px;
                z-index: 97;
            }
                .luawa_block h4 a {
                    float: right;
                    box-sizing: border-box;
                    border: none;
                    background: #F1F1F1;
                    border: 1px solid #D7D7D7;
                    border-width: 0 1px;
                    margin-top: -5px;
                    margin-right: -5px;
                    padding-top: 5px;
                    padding: 5px 15px 29px 10px;
                    height: 24px;
                    position: relative;
                    cursor: pointer;
                }
                .luawa_block h4 a:hover {
                    color: #333;
                }
                .luawa_block h4 a.active {
                    background: #FFF;
                    color: #333;
                }
                .luawa_block h4 a.luawa_external {
                    background: white;
                    border-right: none;
                    color: rgb(40, 40, 137);
                    padding-right: 5px;
                }
                .luawa_block h4 a.luawa_external:hover {
                    color: rgb(0, 0, 17);
                }
            .luawa_block .luawa_sublock {
                top: 35px;
                bottom: 0;
                position: absolute;
                overflow-x: hidden;
                overflow-y: auto;
            }
            .luawa_top .luawa_sublock {
                bottom: 25px;
            }

        div#luawa_app_data {
            left: 0;
            background: #FFF;
            word-wrap: break-word;
        }
        div.luawa_data, div.luawa_messages, div.luawa_status {
            display: none;
        }

        div#luawa_request_data {
            right: 0;
            background: #FFF;
            border-left: 1px solid #D7D7D7;
        }

        div.luawa_stack {
            bottom: 0;
        }
            div.luawa_stack h4 {
                color: black;
            }
                div.luawa_stack table th {
                    background: orange;
                }
                div.luawa_stack table tr td {
                    background: rgb(40, 40, 137);
                    color: white;
                    cursor: pointer;
                    vertical-align: top;
                    border-top: 3px solid black;
                }
                div.luawa_stack table tr:hover td {
                    background: rgb(0, 0, 117);
                }
            div.luawa_stack table tr.luawa_small {
                display: none;
            }
                div.luawa_stack table tr.luawa_small td {
                    font-size: 13px;
                    padding: 1px 5px;
                    background: #FFFECC;
                    color: black;
                    border: none;
                }
                    div.luawa_stack table tr.luawa_small td {
                        cursor: default;
                    }
                    div.luawa_stack table tr.luawa_small table tr:hover td {
                        background: #EEEDBB;
                    }

        div#luawa_internal_data {
            bottom: 0;
            right: 0;
            background: #EFEFEF;
            border-right: 1px solid #D7D7D7;
        }
    </style>

    <div id="luawa_debug_resizer">&uarr; resize &darr;</div>

    <div id="luawa_app_data" class="luawa_block luawa_twothird luawa_top">
        <h4>
            Serverside Messages
            <a href="http://doc.luawa.com" class="luawa_external">Luawa Documentation</a>
            <a id="luawa_show_data" data-tab-id="luawa_data">show template data</a>
            <a id="luawa_show_messages" data-tab-id="luawa_messages">show messages</a>
            <a id="luawa_show_stack" data-tab-id="luawa_stack" class="active">show stack/profiler</a>
        </h4>

        <div class="luawa_messages luawa_sublock">
            <? for key, log in pairs(self:get('debug_logs')) do ?>
                <? for k, message in pairs(log) do ?>
                    <strong><?=key ?></strong>:
                    <pre><?=message.text ?></pre><br />
                    <? if message.stack then ?>
                        <pre><?=message.stack ?></pre>
                    <? end ?>
                <? end ?>
            <? end ?>
        </div>

        <div class="luawa_data luawa_sublock">
            <pre><?=luawa.utils.table_string(self:get('debug_data')) ?></pre>
        </div>

        <div class="luawa_stack luawa_sublock">
            <table>
                <thead><tr>
                    <th>File</th>
                    <th>Time</th>
                    <th>Lines</th>
                </tr></thead>
                <tbody>
                    <? for k, v in pairs(self:get('debug_stack')) do ?>
                        <tr data-stack="<?=k ?>">
                            <td><?=v.file ?></td>
                            <td><?=v.data.time ?>ms</td>
                            <td><?=v.data.lines ?></td>
                        </tr>
                        <tr class="luawa_small luawa_stack_<?=k ?>">
                            <td><table>
                                <tr>
                                    <th>Function</th>
                                    <th>Time</th>
                                    <th>Lines</th>
                                </tr>
                                <? for c, d in pairs(v.data.funcs) do ?>
                                    <tr>
                                        <td><?=d.name ?></td>
                                        <td><?=d.time ?>ms</td>
                                        <td><?=d.lines ?></td>
                                    </tr>
                                <? end ?>
                            </table></td>
                            <td colspan="2"><table>
                                <tr>
                                    <th>Line</th>
                                    <th>Time</th>
                                    <th>Count</th>
                                </tr>
                                <? for c, d in pairs(v.data.line_counts) do ?>
                                    <tr>
                                        <td><?=d.line ?></td>
                                        <td><?=d.time ?>ms</td>
                                        <td><?=d.count ?></td>
                                    </tr>
                                <? end ?>
                            </table></td>
                        </tr>
                    <? end ?>
                </tbody >
            </table>
        </div>
    </div>

    <div id="luawa_request_data" class="luawa_block luawa_third luawa_top">
        <h4>
            Request Data
            <a id="luawa_show_status" data-tab-id="luawa_status">show status</a>
            <a id="luawa_show_request_data" data-tab-id="luawa_request_data" class="active">show request data</a>
        </h4>

        <div class="luawa_request_data luawa_sublock">
            <table>
                <tbody>
                    <tr>
                        <td>Request Time<br /><small>(app + luawa)</small></td>
                        <td><span><?=self:get('debug_request_time') ?>ms</span></td>
                    </tr><tr>
                        <td>App Time</td>
                        <td><span><?=self:get('debug_app_time') ?>ms</span></td>
                    </tr><tr>
                        <td>Luawa Time</td>
                        <td><span><?=self:get('debug_luawa_time') ?>ms</span></td>
                    </tr><tr>
                        <td>Debug Time</td>
                        <td><span><?=self:get('debug_debug_time') ?>ms</span></td>
                    </tr><tr>
                        <td>Hostname</td>
                        <td><?=luawa.request.hostname ?>:<?=luawa.request.hostport ?></td>
                    </tr><tr>
                        <td>Method</td>
                        <td><?=luawa.request.method ?></td>
                    </tr><tr>
                        <td>Remote IP</td>
                        <td><?=luawa.request.remote_addr ?></td>
                    </tr>
                    <tr>
                        <th colspan="2">Cookies</th>
                    </tr>
                    <? for k, v in pairs(luawa.request.cookie) do ?>
                        <tr>
                            <td><?=k ?></td>
                            <td><?=v ?></td>
                        </tr>
                    <? end ?>
                    <tr>
                        <th colspan="2">GET Data</th>
                    </tr>
                    <? for k, v in pairs(luawa.request.get) do ?>
                        <tr>
                            <td><?=k ?></td>
                            <td><?=v ?></td>
                        </tr>
                    <? end ?>
                    <tr>
                        <th colspan="2">POST data</th>
                    </tr>
                    <? for k, v in pairs(luawa.request.post) do ?>
                        <tr>
                            <td><?=k ?></td>
                            <td><?=v ?></td>
                        </tr>
                    <? end ?>
                    <tr>
                        <th colspan="2">Headers</th>
                    </tr>
                    <? for k, v in pairs(luawa.request.header) do ?>
                        <tr>
                            <td><?=k ?></td>
                            <td><?=v ?></td>
                        </tr>
                    <? end ?>
                </tbody>
            </table>
        </div>

        <div class="luawa_status luawa_sublock">
            <table>
                <tbody>
                    <tr>
                        <td>Luawa Root</td>
                        <td><span><?=luawa.root ?></span></td>
                    </tr><tr>
                        <td>Luawa Version</td>
                        <td><span><?=luawa.version ?></span></td>
                    </tr><tr>
                        <td>Nginx Version</td>
                        <td><span><?=self:get('nginx_version') ?></span></td>
                    </tr><tr>
                        <td>Nginx-Lua Version</td>
                        <td><span><?=self:get('nginx_lua_version') ?></span></td>
                    </tr><tr>
                        <th colspan="2">Cache</th>
                    </tr><tr>
                        <td>Enabled</td>
                        <td><span><? if luawa.caching then ?>true<? else ?>false<? end ?></span></td>
                    </tr><tr>
                        <td>App Files</td>
                        <td><?=self:get('debug_cached_files') ?></td>
                    </tr><tr>
                        <td>Template</td>
                        <td><?=self:get('debug_cached_templates') ?></td>
                    </tr><tr>
                        <th colspan="2">Session Objects</th>
                    </tr><tr>
                        <td>Requests Served</td>
                        <td><span><?=luawa.requests:get('success') ?></span></td>
                    </tr><tr>
                        <td>Errors Served</td>
                        <td><span><?=luawa.requests:get('error') ?></span></td>
                    </tr><tr>
                        <td>Session</td>
                        <td><?=#ngx.shared[luawa.shm_prefix .. 'session']:get_keys(0) ?></td>
                    </tr><tr>
                        <td>User</td>
                        <td><?=#ngx.shared[luawa.shm_prefix .. 'user']:get_keys(0) ?></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</div><!--end debug-->

<a id="luawa_debug_button" href="#">debug &uarr;</a>



<!--script-->
<script type="text/javascript">
    window.addEventListener('load', (function() {
        'use strict';

        //core
        var html = document.querySelector('html'),
            debug = document.querySelector('#luawa_debug'),
            debug_img = document.querySelector('#luawa_img'),
            debug_button = document.querySelector('#luawa_debug_button'),
            debug_resizer = document.querySelector('#luawa_debug_resizer'),
            visible,
            height;

        //toggle the debug
        function debug_toggle() {
            //if displayed
            if(debug.style.display == 'block') {
                debug.style.display = 'none';
                debug_img.style.display = 'none';
                sessionStorage.setItem('luawa_debug', 'false');
                debug_button.innerHTML = 'debug &uarr;';
                html.style.marginBottom = '0px';
                visible = false;
            //if not displayed
            } else {
                debug.style.display = 'block';
                debug_img.style.display = 'block';
                sessionStorage.setItem('luawa_debug', 'true');
                debug_button.innerHTML = 'debug &darr;';
                html.style.marginBottom = (window.innerHeight - height) + 'px';
                visible = true;
            }

            return false;
        }

        //toggle if saved
        if(sessionStorage.getItem('luawa_debug') == 'true') {
            debug_toggle();
        }

        //stop scrolling when over debug (annoying)
        debug.addEventListener('mouseover', function() {
            document.body.style.overflow = 'hidden';
        });
        debug.addEventListener('mouseout', function() {
            document.body.style.overflow = 'auto';
        });

        //resize if saved
        if(sessionStorage.getItem('luawa_debug_top')) {
            debug.style.top = sessionStorage.getItem('luawa_debug_top') + 'px';
        }

        var start_height = debug.offsetTop;
        //hacky- but we need the height
        if(!visible) {
            debug_toggle();
            start_height = debug.offsetTop;
            debug_toggle();
        }

        //resize debug
        var mouse_y;
        var mouseMove = function(ev) {
            ev.preventDefault();
            if(!mouse_y) {
                mouse_y = ev.clientY;
            }
            var diff = ev.clientY - mouse_y;
            var top = start_height + diff;
            if(top < 0)
                top = 0;
            debug.style.top = top + 'px';
            html.style.marginBottom = (window.innerHeight - top) + 'px';
            height = top;
            sessionStorage.setItem('luawa_debug_top', top);
        };
        debug_resizer.addEventListener('mousedown', function(ev) {
            window.addEventListener('mousemove', mouseMove);
        });
        window.addEventListener('mouseup', function(ev) {
            window.removeEventListener('mousemove', mouseMove);
        });
        if(visible) {
            html.style.marginBottom = (window.innerHeight - start_height) + 'px';
            height = start_height;
        }

        //toggle debug
        debug_button.addEventListener('click', function(ev) {
            ev.preventDefault();
            debug_toggle();
        });


        //tab buttons
        var app_data_buttons = document.querySelectorAll('#luawa_debug h4 a[data-tab-id]');
        //button clicks
        for(var i=0; i<app_data_buttons.length; i++) {
            app_data_buttons[i].addEventListener('click', function(ev) {
                ev.preventDefault();
                var buttons = this.parentNode.querySelectorAll('a');
                for(var i =0; i<buttons.length; i++) {
                    buttons[i].classList.remove('active');
                }
                this.className = 'active';

                var sub_block = this.parentNode.parentNode;
                var tabs = sub_block.querySelectorAll('.luawa_sublock');
                for(var i=0; i<tabs.length; i++) {
                    tabs[i].style.display = 'none';
                }
                var tab = document.querySelector('.' + this.getAttribute('data-tab-id'));
                tab.style.display = 'block';

                var open_tabs = JSON.parse(sessionStorage.getItem('luawa_tabs')) || {};
                if(typeof open_tabs != 'object') open_tabs = {};
                open_tabs[sub_block.id] = this.getAttribute('data-tab-id');
                sessionStorage.setItem('luawa_tabs', JSON.stringify(open_tabs));
            });
        }

        //remember open tabs
        var tabs = JSON.parse(sessionStorage.getItem('luawa_tabs')) || {};
        if(typeof tabs != 'object') tabs = {};
        for(var key in tabs) {
            var $el = document.querySelector('#' + key + ' h4 a[data-tab-id=' + tabs[key] + ']');
            $el.click();
        }


        //profiler
        var files = document.querySelectorAll('.luawa_stack tbody tr[data-stack]');
        for(var i=0; i<files.length; i++) {
            files[i].addEventListener('click', function(ev) {
                var rows = document.querySelector('.luawa_stack tbody .luawa_stack_' + this.getAttribute('data-stack'));
                if(this.open) {
                    rows.style.display = 'none';
                    this.open = false;
                } else {
                    rows.style.display = 'table-row';
                    this.open = true;
                }
            });
        }
    }));
</script>



<a id="luawa_img" href="http://luawa.com">
    <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAw8AAAJQCAYAAADIc1hAAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyRpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNiAoTWFjaW50b3NoKSIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo3RUZBRTU3OUQwMDYxMUUzQTkwM0Q1QUE5QUMzOTUzNCIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDo3RUZBRTU3QUQwMDYxMUUzQTkwM0Q1QUE5QUMzOTUzNCI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjdFRkFFNTc3RDAwNjExRTNBOTAzRDVBQTlBQzM5NTM0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjdFRkFFNTc4RDAwNjExRTNBOTAzRDVBQTlBQzM5NTM0Ii8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+2UfRZwAA9cpJREFUeNrsvQl8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8kxNTZ177ty5WA8Pj8bFixevGTRoUBE9A8DVMG3JRZw8eXKoDg6tPp81NTV//uc///nT7du3J9FjANAxsrKyolasWPGSDg6f6sPlTU1Nb6akpMyXQEHvAHA1jDy4kMOHDyd8/vnn069evfrWLR6aHBERcXH+/PkpISEh1fQcALTPjh07ktLS0sapm6eLqpiYmEVLliz5mF4C4Ep6/O53v6MXXERkZOSluLi4k9nZ2edqamr26psetvPQh00m05yjR48WBwQElPfv37+Y3gOAtispKfFbu3btwszMzLtbCg7i8uXLB+vr6z2GDBmSS48BcBWMPLiodevWzc7Kyoq396FmIzkhISFjwYIFW+k1ALi1I0eODN2yZcvMNry/qoCAgJeXLVv2Dr0GgPAAh7dv377Ru3bteqC1RdTWAKE/4EyzZs3aGBcXV0jPAcDNZA3D5s2bZ7b1i5nBgwdnz507N1W/vzbSewAID3AKBQUFwbJwr7y8PKgtH3aJiYmHHnvssV30HABcJxtuymhDdXX1X275werh8foDDzywa9KkSZRrBUB4gHPasGHDoydOnBjelgARHBxcOnv27I3R0dGshQDg9jZt2jQtPT19ZFveP4OCgsrnzZuXEhUVVUrPASA8wKnpD7/4bdu2PVpfX/+nNjw8ecKECfsffvjhvfQcAHd05syZSB0cZptMpoC2BIdhw4admD9//jZ6DgDhAS6juLjYTzYyunDhQmRbPgxDQkKKZ82atZlRCADuZOPGjdOOHTvWltEG5e3t/dr06dO3jxo1KpOeA0B4gEvatWvXuL17906SzYza8PBkmb97//33H6LnALgyWdvw2WefzWjraEN0dHTunDlzNvbt27eG3gPgDrzoAvekw0BafHz86X/961/lpaWlwbf6kIyMjKQKEwCXJZWUJDTo8DC0DaFBeXp6vj516lQWRQNwO4w8QG3duvWBw4cPJ9r5wEweOXJk+qxZs76gpwC4Itm34csvv5xWU1Pz5zY8PDksLKxISrBGRERU0HsACA9wS7IwUOqXV1ZWBtqGCDY4AuDKDh8+nLB169YZqg2jDRIcxo8fv3/atGkUkgBAeACEDhAPHT16dLTlgzT5iSee+Piuu+7KpWcAuKq33377ubKysvdaCw2hoaFSPGIjJVgBEB4ID2jm7NmzkVu2bJkRHR2dP2/ePMoOAnBp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" />
</a>]]

return template
