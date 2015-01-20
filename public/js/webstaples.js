/* An offset of the server time, allows for calibration to bell time */
var GLOBAL_TIME_OFFSET = -37;

var serverTimeObj = {};
var timeOffset = 0;

var now = null;
var then = null;
var serverSecs = 0;
var localSecs = 0;

$.getJSON('/api/time', null, function (data) {
    serverTimeObj = data;
    serverSecs = (+serverTimeObj.hours * 60 + serverTimeObj.mins) * 60 + serverTimeObj.secs;

    now = new Date();
    then = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    localSecs = ((now.getTime() - then.getTime()) / 1000);

    timeOffset = serverSecs - localSecs;
    timeOffset -= GLOBAL_TIME_OFFSET;
});

function t(h, m) {
    return (h * 60 + m) * 60;
}

var schedule = {};
$.getJSON('/api/schedule?date=today', null, function (data) {
    schedule = data;
    schedule.push({
        name: 'Contact coder if you see this',
        start_seconds: -5,
        end_seconds: -5
    });
});

var user_schedule = {};
$.getJSON('/cur_auth_sched', null, function (data) {
    user_schedule = data;
});

var percentComplete = 0;
var currentClass = null;

var announcements = {};
$.getJSON('/api/announcements/today', null, function (data) {
    announcements = data;
});

var userProfile = {};
$.getJSON('/cur_usr_profile', null, function (data) {
    userProfile = data;
});

setTimeout(function () {

    $.material.init();

    var ancTxt = "\n";

    for (var curAnc = 0; curAnc < announcements.length; curAnc += 2) {
        ancTxt += '<div class="row">\n';

        if (curAnc != announcements.length - 1) {
            ancTxt += '<div class="col-md-6">\n' +
            '<h3>' + announcements[curAnc].title + '</h3>\n' +
            '<p>' + announcements[curAnc].body + '</p>\n' +
            '</div>\n';
            ancTxt += '<div class="col-md-6">\n' +
            '<h3>' + announcements[curAnc + 1].title + '</h3>\n' +
            '<p>' + announcements[curAnc + 1].body + '</p>\n' +
            '</div>\n';
        } else {
            ancTxt += '<div class="col-md-12">\n' +
            '<h3>' + announcements[curAnc].title + '</h3>\n' +
            '<p>' + announcements[curAnc].body + '</p>\n' +
            '</div>\n';
        }

        ancTxt += '</div>\n';
    }


    $('#announcementZone').html(ancTxt);

    var i = 0;
    $('.page').not("#announcements").each(function () {
        var cls = schedule[i];
        $(this).find('h1').first().text(user_schedule.code == 0 ? cls.name + ": " + user_schedule[cls.name] : cls.name);
        i++;
    });

    i = 0;
    $('.menu li span').each(function () {
        var cls = schedule[i];

        if ((cls.name == "1" || cls.name == "2" || cls.name == "3" || cls.name == "4" || cls.name == "5" || cls.name == "6" || cls.name == "7" || cls.name == "8") && user_schedule.code == 0) {
            $(this).text(cls.name + ": " + user_schedule[cls.name]);
        } else {
            $(this).text(cls.name);
            if (user_schedule.code != 100) {
                console.log("Could not load your classes, error code " + user_schedule.code + " with data of " + user_schedule.err_str);
            }
        }

        i++;
    });

    i = 1;
    $('.config-input-class').each(function () {
        $(this).val(user_schedule[String(i)]);
        i++;
    });

    /* Updates Class Header */
    setInterval(function () {
        /* Gets the header for the timer at the bottom of the page, which displays what the current class is, also messages when opening the page */
        var timerHeader = $("#timerHeader");

        /*
         * Very long if statement, time for a very long comment
         * This if statement checks to see if the header for the timer is what it should be at any given time, if isn't then it will make it correct, as well as playing the transition animation
         * The first comparison checks if it the current class is null, which would mean there's no school. This makes the if statement check if the header text isn't "No School"
         * If the current class has been set somewhere, it then checks if the users schedule was successfully retrieved, if not, it just checks the classes name/id against the text
         * If the users schedule was retrieved, it checks the title against the class name/id, and the users schedule
         * After all the checking, it sets the header to what it should be, and if the final check returned false, then it doesn't do anything and continues the loop
         */
        if (currentClass != null ? ( user_schedule.code == 0 ? (currentClass.name + ": " + user_schedule[currentClass.name] != timerHeader.text()) : (currentClass.name != timerHeader.text())) : timerHeader.text() != "No School") {
            timerHeader.addClass("active").fadeOut(800, function () {
                $(this).removeClass("active");

                if (currentClass != null)
                    if (user_schedule.code == 0 && currentClass.name != "Passing Time") {
                        timerHeader.text(currentClass.name + ": " + user_schedule[currentClass.name]);
                    } else {
                        timerHeader.text(currentClass.name)
                    }
                else {
                    timerHeader.text("No School");
                }

                setTimeout(function () {
                    $(this).fadeIn(800);
                }.bind(this), 100);
            });
        }
    }, 4000);

    /* Updates time and current class */
    setInterval(function () {
        now = new Date();
        then = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
        var secsSinceMidnight = ((now.getTime() - then.getTime()) / 1000) + timeOffset;

        var changed = false;

        for (var classId = 0; classId < schedule.length - 1; classId++) {
            if (schedule[classId].start_seconds < secsSinceMidnight && secsSinceMidnight < schedule[classId].end_seconds) {
                currentClass = schedule[classId];

                changed = true;

                break;
            } else if (schedule[classId].end_seconds < secsSinceMidnight && secsSinceMidnight < schedule[classId + 1].start_seconds) {
                currentClass = {
                    name: "Passing Time",
                    start_seconds: schedule[classId].end_seconds,
                    end_seconds: schedule[classId + 1].start_seconds
                };

                changed = true;

                $('.menu li[data-target="#class' + (classId + 1) + '"]').addClass('btn-material-grey');
                break;
            } else {
                $('.menu li[data-target="#class' + (classId + 1) + '"]').addClass('btn-material-grey');
            }
        }

        if (changed == false) {
            currentClass = null;
        }

        hours = Math.floor(secsSinceMidnight / 60 / 60);
        totalMins = Math.floor(secsSinceMidnight / 60);
        min = totalMins == 0 ? "00" : ((totalMins % 60 < 10) ? "0" + totalMins % 60 : totalMins % 60);
        $("#clockTime").text((hours > 12 ? hours - 12 : hours) + ":" + min + (hours >= 12 ? " PM" : " AM"));

        if (currentClass != null) {
            $(".menu li").each(function () {
                if ($(this).data('target') != '#class' + (classId + 1) ||
                    currentClass.name == "Passing Time") {
                    $(this).removeClass('staples-blue');
                    return;
                }
                $(this).addClass('staples-blue');
            });

            percentComplete = Math.round((secsSinceMidnight - currentClass.start_seconds) / (currentClass.end_seconds - currentClass.start_seconds) * 10000) / 100;

            var timeThroughCurrentClass = currentClass.end_seconds - secsSinceMidnight;
            var totalMins = Math.floor(timeThroughCurrentClass / 60);
            var min = totalMins == 0 ? "00" : ((totalMins < 10) ? "0" + totalMins : totalMins);
            var sec = Math.floor(timeThroughCurrentClass % 60);
            sec = sec == 0 ? "00" : ((sec < 10) ? "0" + sec : sec);

            $("#currentTime").text("-" + min + ":" + sec).css("margin-left", percentComplete + "%").css("margin-left", "-=1.5em");

            var hours = Math.floor(currentClass.start_seconds / 60 / 60);
            totalMins = Math.floor(currentClass.start_seconds / 60);
            min = totalMins == 0 ? "00" : ((totalMins % 60 < 10) ? "0" + totalMins % 60 : totalMins % 60);
            $("#startTime").text((hours > 12 ? hours - 12 : hours) + ":" + min + (hours >= 12 ? " PM" : " AM"));

            hours = Math.floor(currentClass.end_seconds / 60 / 60);
            totalMins = Math.floor(currentClass.end_seconds / 60);
            min = totalMins == 0 ? "00" : ((totalMins % 60 < 10) ? "0" + totalMins % 60 : totalMins % 60);
            $("#endTime").text((hours > 12 ? hours - 12 : hours) + ":" + min + (hours >= 12 ? " PM" : " AM"));
        } else {
            $("#startTime").text("0:00");
            $("#endTime").text("0:00");
            $("#currentTime").text("-0:00").css("margin-left", 0 + "%").css("margin-left", "-=1.5em");
        }
    }, 20);

    /* Sets the progress of the timer bar */
    setInterval(function () {
        if (currentClass != null) {
            $("#classProgress").css("width", percentComplete + "%")
        } else {
            $("#classProgress").css("width", 0 + "%")
        }
    }, 200);

}, 2000);

$(".menu li").click(function () {
    if ($(this).is('.active')) return;
    $(".menu li").removeClass("active").removeClass("shadow-z-3").addClass("shadow-z-2").find('.status-band').removeClass('btn-success');
    $(this).addClass("active").addClass("shadow-z-3").removeClass("shadow-z-2").find('.status-band').addClass('btn-success');

    var target = $($(this).data('target'));

    var oldPage = $('.page.active');
    oldPage.removeClass('active');

    setTimeout(function () {
        oldPage.fadeOut(0);
        target.fadeIn(0);

        target.addClass('active');
    }, 400);
});