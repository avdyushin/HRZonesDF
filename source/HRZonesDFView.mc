import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;
import Toybox.WatchUi;

class Point {
    var x;
    var y;
    public function initialize(x, y) {
        self.x = x;
        self.y = y;
    }
}

class Size {
    var width;
    var height;
    public function initialize(width, height) {
        self.width = width;
        self.height = height;
    }
}

class Range {
    var start;
    var end;
    var size;
    public function initialize(start, end) {
        self.start = start;
        self.end = end;
        self.size = end - start;
    }
}

function max(a as Number, b as Number) as Number { return a > b ? a : b; }
function min(a as Number, b as Number) as Number { return a < b ? a : b; }
function clamp(value as Number, min as Number, max as Number) as Number { return min(max(min, value), max); }

class HRZonesDFView extends WatchUi.DataField {

    private enum FieldPosition {
        TOP, BOTTOM, LEFT, RIGHT, MIDDLE, FULL
    }

    private const MIN_HR = 0;
    private const MAX_HR = 255;
    private const MIN_ZONE = 0;
    private const MAX_ZONE = 5;
    private const DEG = 57.29578f;
    private const BAR_H = 20f;

    hidden var hrZones as Toybox.Lang.Array<Number>;
    hidden var hrRanges as Toybox.Lang.Array<Number>;

    private var mScreenSize as Size;

    // Set the label of the data field here.
    function initialize() {
        DataField.initialize();

        hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);

        hrRanges = new [hrZones.size() + 2];
        hrRanges[0] = MIN_HR;
        for (var i = 0; i < hrZones.size(); ++i) {
            hrRanges[i + 1] = hrZones[i];
        }
        hrRanges[hrRanges.size() - 1] = MAX_HR;

        // for (var i = 0; i < hrRanges.size(); ++i) {
        //     System.println("range [" + i + "] = " + hrRanges[i]);
        // }

        var ds = System.getDeviceSettings();
        mScreenSize = new Size(ds.screenWidth, ds.screenHeight);
    }


    hidden function getZone() as Toybox.Lang.Number {
        var hr = clamp(hrValue, MIN_HR, MAX_HR);
        for (var i = 0; i < hrRanges.size() - 1; ++i) {
            var min = hrRanges[i];
            var max = hrRanges[i + 1];
            if (hr >= min && hr < max) {
                return i;
            }
        }
        return 0;
    }

    hidden var hrValue;
    hidden var hrZone = 0;

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void {
        // See Activity.Info in the documentation for available information.
        if (info has :currentHeartRate) {
            if (info.currentHeartRate != null) {
                hrValue = info.currentHeartRate;
                hrZone = min(MAX_ZONE, getZone());
            } else {
                hrValue = 0.0f;
                hrZone = MIN_ZONE;
            }
        }
    }

    private var mViewSize = new Size(0, 0);

    private function calculateSizes(dc as Dc) {
        mViewSize = new Size(dc.getWidth(), dc.getHeight());
    }

    function onLayout(dc as Dc) {
        calculateSizes(dc);
    }

    private function getCenterPoint(asPos as FieldPosition) {
        switch (asPos) {
        case FULL:
            return new Point(mScreenSize.width * 0.5f, mScreenSize.height * 0.5f);
        case MIDDLE:
            return new Point(mScreenSize.width * 0.5f, mViewSize.height * 0.5f);
        case BOTTOM:
            return new Point(mScreenSize.width * 0.5f, -(mScreenSize.height * 0.5f - mViewSize.height));
        case TOP:
            return new Point(mScreenSize.width * 0.5f, mViewSize.height + (mScreenSize.height * 0.5f - mViewSize.height));
        default:
            return new Point(mScreenSize.width * 0.5f, mScreenSize.height * 0.5f);
        }
    }

    private function getFieldPosition() as FieldPosition {
        var obscurity = getObscurityFlags();
        var pos = FULL;
        if (obscurity == (OBSCURE_BOTTOM | OBSCURE_LEFT | OBSCURE_RIGHT | OBSCURE_TOP)) {
            pos = FULL;
        } else if (obscurity == (OBSCURE_LEFT | OBSCURE_RIGHT)) {
            pos = MIDDLE;
        } else if (obscurity & OBSCURE_TOP > 0) {
            pos = TOP;
        } else if (obscurity & OBSCURE_BOTTOM > 0) {
            pos = BOTTOM;
        } else if (obscurity & OBSCURE_LEFT > 0) {
            pos = LEFT;
        } else if (obscurity & OBSCURE_RIGHT > 0) {
            pos = RIGHT;
        }
        return pos;
    }

    private function barColor(zone) {
        switch (zone) {
            case 0:
            case 1:
                return Graphics.COLOR_DK_GRAY;
            case 2:
                return Graphics.COLOR_DK_BLUE;
            case 3:
                return Graphics.COLOR_DK_GREEN;
            case 4:
                return Graphics.COLOR_YELLOW;
            case 5:
                return Graphics.COLOR_DK_RED;
            default:
                return Graphics.COLOR_WHITE;
        }
    }

    private function barYOffset(atPos as FieldPosition) {
        switch (atPos) {
        case MIDDLE:
        case TOP:
            return mViewSize.height - BAR_H;
        case FULL:
            return mViewSize.height / 2 - BAR_H / 2;
        default:
            return 0;
        }
    }

    private function drawCircleBar(dc as Dc, atPos as FieldPosition) {
        var center = getCenterPoint(atPos);
        var direction = getIndicatorDirection(atPos);
        var color = Graphics.COLOR_PINK;
        var penWidth = 7;
        dc.setColor(color, color);
        dc.setPenWidth(penWidth);
        // dc.drawLine(center.x, center.y, center.x + 30, center.y + 90 * direction);
        var dy = mScreenSize.height * 0.5f - mViewSize.height;
        var dx = mViewSize.width * 0.5f;
        var a = Math.atan2(dy, dx) * DEG + 5;
        var degreeStart = 180 + a * direction;
        // var degreeEnd = 0 - a * direction;
        var r = mScreenSize.height * 0.5f - 8;
        var maxDegree = 180 - a * 2f;
        // System.println("----- pos " + atPos);
        // System.println("max degree = " + maxDegree);
        var hrRange = new Range(hrZones[0], hrZones[hrZones.size() - 1]);
        // System.println("hr range = " + hrRange.start + " to " + hrRange.end + " size " + hrRange.size);
        var ratio = maxDegree / (hrRange.size + 1) * 1f;
        // System.println("ratio = " + ratio);
        var attr = direction == -1 ? Graphics.ARC_CLOCKWISE : Graphics.ARC_COUNTER_CLOCKWISE;
        var active_start = 0;
        var active_end = 0;
        for (var i = 0; i < hrZones.size() - 1; ++i) {
            var start = (hrZones[i] - hrRange.start) * ratio;
            var length = (hrZones[i + 1] - hrZones[i]) * ratio;
            dc.setColor(barColor(i + 1), barColor(i + 1));
            var ds = degreeStart + start * direction;
            var de = ds + length * direction;
            if (i + 1 == hrZone) {
                active_start = ds;
                active_end = de;
            } else {
                dc.drawArc(center.x, center.y, r, attr, ds + 0.5f * direction, de - 1f * direction);
            }
        }
        if (active_start != 0 && active_end != 0) {
            dc.setPenWidth(penWidth + 6);
            dc.setColor(barColor(hrZone), barColor(hrZone));
            dc.drawArc(center.x, center.y, r, attr, active_start, active_end);
        }
        var clamp = clamp(hrValue, hrRange.start, hrRange.end) - hrRange.start;
        var indicatorDegree = degreeStart + clamp * ratio * direction;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.setPenWidth(14);
        dc.drawArc(center.x, center.y, r - 5, attr, indicatorDegree - 1.25f * direction, indicatorDegree + 2.5f * direction);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.drawArc(center.x, center.y, r - 5, attr, indicatorDegree - 1f * direction, indicatorDegree + 2f * direction);
    }

    private function drawBar(dc as Dc, atPos as FieldPosition) {
        var dy = barYOffset(atPos);
        var hrRange = new Range(hrZones[0], hrZones[hrZones.size() - 1]);
        var ratio = mViewSize.width * 1f / hrRange.size * 1f;
        var active_dx = 0;
        var active_dy = 0;
        var active_w = 0;
        var active_h = 0;
        for (var i = 0; i < hrZones.size() - 1; ++i) {
            var dx = hrZones[i] - hrRange.start;
            var w = hrZones[i + 1] - hrZones[i];
            if (i + 1 == hrZone) {
                active_dx = dx * ratio - 2;
                active_dy = dy - 2;
                active_w = w * ratio + 4;
                active_h = BAR_H + 6;
            } else {
                dc.setColor(barColor(i + 1), Graphics.COLOR_BLACK);
                dc.fillRectangle(dx * ratio + 1, dy + 1, w * ratio - 2, BAR_H - 2);
            }
        }
        dc.setColor(barColor(hrZone), Graphics.COLOR_BLACK);
        dc.fillRectangle(active_dx, active_dy, active_w, active_h);

        // indicator
        var clamp = clamp(hrValue, hrRange.start, hrRange.end);
        var dx = (clamp - hrRange.start) * ratio;
        dy = barYOffset(atPos) + getIndicatorOffset(atPos);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        var dir = getIndicatorDirection(atPos);
        dc.fillPolygon([
            [dx - 7, dy + dir * 2],
            [dx + 7, dy + dir * 2],
            [dx, dy + getIndicatorEnd(atPos) - dir * 2],
        ]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillPolygon([
            [dx - 5, dy],
            [dx + 5, dy],
            [dx, dy + getIndicatorEnd(atPos)],
        ]);
    }

    private function getIndicatorDirection(atPos as FieldPosition) {
        switch (atPos) {
            case MIDDLE:
            case TOP:
            case FULL:
                return -1;
            default:
                return 1;
        }
    }

    private function getIndicatorOffset(atPos as FieldPosition) {
        switch (atPos) {
            case MIDDLE:
            case TOP:
                return -8;
            case FULL:
                return -8;
            default:
                return BAR_H + 8;
        }
    }

    private function getIndicatorEnd(atPos as FieldPosition) {
        switch (atPos) {
            case MIDDLE:
            case TOP:
                return +10;
            case FULL:
                return +10;
            default:
                return -10;
        }
    }

    private function getLabelOffset(atPos as FieldPosition) {
        switch (atPos) {
            case TOP: 
                return 10;
            case BOTTOM:
                return -10;
            case MIDDLE:
                return -10;
            case FULL:
                return -40;
            default:
                return 10;
        }
    }

    private function isZoneLabelVisible(atPos as FieldPosition) {
        switch (atPos) {
            case FULL:
                return true;
            default:
                return false;
        }
    }

    private function getFont(atPos as FieldPosition) {
        switch (atPos) {
            case TOP:
            case BOTTOM:
                return Graphics.FONT_NUMBER_MILD;
            default:
                return Graphics.FONT_NUMBER_MILD;
        }
    }

    function onUpdate(dc as Dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var pos = getFieldPosition();
        var labelOffset = getLabelOffset(pos);
        dc.drawText(
            mViewSize.width / 2f,
            mViewSize.height / 2f + labelOffset,
            getFont(pos), 
            hrValue.format("%d"), 
            (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER)
        );
        if (isZoneLabelVisible(pos)) {
            dc.drawText(
                mViewSize.width / 2f,
                mViewSize.height / 2f + 20,
                Graphics.FONT_SYSTEM_XTINY, 
                "zone " + hrZone.format("%d"), 
                (Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER)
            );
        }
        switch (pos) {
            case TOP:
            case BOTTOM: {
                drawCircleBar(dc, pos);
                break;
            }
            default: {
                drawBar(dc, pos);
                break;
            }
        }
    }
}
