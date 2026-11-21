#!/usr/bin/env bash
set -euo pipefail

APP="source/app/src/main"
rm -rf "$APP" source/app/src/test source/app/src/androidTest
mkdir -p "$APP/java/de/antiafk/assistant" "$APP/res/xml" "$APP/res/values"

cat > "$APP/AndroidManifest.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="false"
        android:label="Anti-AFK Assistant"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.Material.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <service
            android:name=".AutoClickAccessibilityService"
            android:label="Anti-AFK Assistant – Klickmenü"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config" />
        </service>
    </application>
</manifest>
XML

cat > "$APP/res/xml/accessibility_service_config.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/accessibility_service_description"
    android:accessibilityEventTypes="typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canPerformGestures="true"
    android:canRetrieveWindowContent="false" />
XML

cat > "$APP/res/values/strings.xml" <<'XML'
<resources>
    <string name="app_name">Anti-AFK Assistant</string>
    <string name="accessibility_service_description">Zeigt ein Bedienfeld mit manuellem Sitzungszähler und einem vom Nutzer gesteuerten Autoklicker an. Liest keine Bildschirminhalte.</string>
</resources>
XML

cat > "$APP/java/de/antiafk/assistant/MainActivity.java" <<'JAVA'
package de.antiafk.assistant;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

public class MainActivity extends Activity {
    private TextView status;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.rgb(14, 18, 30));
        getWindow().setNavigationBarColor(Color.rgb(14, 18, 30));

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setGravity(Gravity.CENTER_HORIZONTAL);
        page.setPadding(dp(24), dp(34), dp(24), dp(24));
        page.setBackgroundColor(Color.rgb(14, 18, 30));

        TextView title = new TextView(this);
        title.setText("Anti-AFK Assistant");
        title.setTextColor(Color.WHITE);
        title.setTextSize(29);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        page.addView(title, matchWrap());

        TextView description = new TextView(this);
        description.setText("Öffne das Bedienfeld über Androids Bedienungshilfen. Danach kannst du es über Roblox oder einer anderen App verwenden.");
        description.setTextColor(0xFFB9C2D8);
        description.setTextSize(16);
        description.setGravity(Gravity.CENTER);
        description.setPadding(0, dp(16), 0, dp(18));
        page.addView(description, matchWrap());

        status = new TextView(this);
        status.setTextColor(0xFFE6EAF5);
        status.setTextSize(15);
        status.setGravity(Gravity.CENTER);
        page.addView(status, matchWrap());

        Button enable = new Button(this);
        enable.setText("Bedienungshilfen öffnen");
        enable.setAllCaps(false);
        enable.setTextSize(16);
        LinearLayout.LayoutParams enableParams = matchWrap();
        enableParams.topMargin = dp(22);
        page.addView(enable, enableParams);
        enable.setOnClickListener(v ->
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        );

        TextView note = new TextView(this);
        note.setText("Im Menü kannst du den Klickpunkt verschieben, den Autoklicker selbst starten/stoppen und deine Sitzungszeit mit AFK AN / AFK AUS erfassen. Es gibt keine automatische Bildschirm- oder Spielfigurensteuerung.");
        note.setTextColor(0xFF929DB8);
        note.setTextSize(13);
        note.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams noteParams = matchWrap();
        noteParams.topMargin = dp(28);
        page.addView(note, noteParams);

        setContentView(page);
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateStatus();
    }

    private void updateStatus() {
        if (status == null) return;
        String enabled = Settings.Secure.getString(
            getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        );
        String component = new ComponentName(this, AutoClickAccessibilityService.class)
            .flattenToString();
        boolean active = !TextUtils.isEmpty(enabled) && enabled.toLowerCase().contains(
            component.toLowerCase()
        );
        status.setText(active
            ? "Bedienfeld ist eingeschaltet. Es sollte als schwebendes Menü angezeigt werden."
            : "Bedienfeld ist noch ausgeschaltet. Aktiviere den Dienst in den Einstellungen.");
        status.setTextColor(active ? 0xFF70D5A0 : 0xFFFFC56B);
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
JAVA

cat > "$APP/java/de/antiafk/assistant/AutoClickAccessibilityService.java" <<'JAVA'
package de.antiafk.assistant;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.graphics.Color;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Locale;

public class AutoClickAccessibilityService extends AccessibilityService {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WindowManager windowManager;
    private View panelView;
    private View targetView;
    private View bubbleView;
    private WindowManager.LayoutParams panelParams;
    private WindowManager.LayoutParams targetParams;
    private WindowManager.LayoutParams bubbleParams;
    private TextView afkTimeText;
    private TextView afkButton;
    private TextView clickerButton;
    private TextView intervalText;

    private boolean sessionRunning = false;
    private long sessionStartedAt = 0L;
    private long accumulatedSessionMs = 0L;

    private boolean clickerRunning = false;
    private long clickIntervalMs = 1000L;
    private int targetWidth;
    private int targetHeight;
    private int clickX;
    private int clickY;
    private int targetX;
    private int targetY;

    private final Runnable timerTicker = new Runnable() {
        @Override public void run() {
            updateAfkTime();
            handler.postDelayed(this, 1000L);
        }
    };

    private final Runnable clickTicker = new Runnable() {
        @Override public void run() {
            if (!clickerRunning) return;
            Path path = new Path();
            path.moveTo(clickX, clickY);
            GestureDescription gesture = new GestureDescription.Builder()
                .addStroke(new GestureDescription.StrokeDescription(path, 0L, 65L))
                .build();
            dispatchGesture(gesture, new GestureResultCallback() {
                @Override public void onCompleted(GestureDescription completedGesture) {
                    // The next click is paced by clickTicker below.
                }
            }, null);
            handler.postDelayed(this, clickIntervalMs);
        }
    };

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        targetWidth = dp(58);
        targetHeight = dp(58);
        createPanel();
        showTarget();
        showBubble();
        hideBubble();
        handler.removeCallbacks(timerTicker);
        handler.post(timerTicker);
    }

    private void createPanel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(12), dp(11), dp(12), dp(12));
        panel.setBackground(roundRect(0xF0202638, dp(18)));
        panel.setElevation(dp(10));

        TextView heading = new TextView(this);
        heading.setText("ANTI-AFK ASSISTANT");
        heading.setTextColor(Color.WHITE);
        heading.setTextSize(13);
        heading.setLetterSpacing(0.08f);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        heading.setPadding(dp(3), dp(2), dp(3), dp(8));
        panel.addView(heading, matchWrap());

        afkTimeText = makeLabel("AFK-Zeit 00:00:00", 17, 0xFFEFF2FF, true);
        panel.addView(afkTimeText, matchWrap());

        afkButton = makeButton("AFK AN", 0xFF246D54);
        LinearLayout.LayoutParams rowButton = matchWrap();
        rowButton.topMargin = dp(8);
        panel.addView(afkButton, rowButton);
        afkButton.setOnClickListener(v -> toggleSession());

        TextView clickLabel = makeLabel("AUTOKLICKER", 12, 0xFFACB7D3, true);
        LinearLayout.LayoutParams clickLabelParams = matchWrap();
        clickLabelParams.topMargin = dp(12);
        panel.addView(clickLabel, clickLabelParams);

        clickerButton = makeButton("Autoklicker START", 0xFF7657E8);
        LinearLayout.LayoutParams clickerParams = matchWrap();
        clickerParams.topMargin = dp(6);
        panel.addView(clickerButton, clickerParams);
        clickerButton.setOnClickListener(v -> toggleClicker());

        LinearLayout intervalRow = new LinearLayout(this);
        intervalRow.setOrientation(LinearLayout.HORIZONTAL);
        intervalRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams intervalRowParams = matchWrap();
        intervalRowParams.topMargin = dp(5);
        panel.addView(intervalRow, intervalRowParams);

        Button slower = makeSmallButton("−");
        intervalRow.addView(slower, new LinearLayout.LayoutParams(0, dp(40), 1f));
        intervalText = makeLabel("1000 ms", 13, 0xFFE3E8F6, true);
        intervalRow.addView(intervalText, new LinearLayout.LayoutParams(0, dp(40), 2f));
        Button faster = makeSmallButton("+");
        intervalRow.addView(faster, new LinearLayout.LayoutParams(0, dp(40), 1f));
        slower.setOnClickListener(v -> setInterval(clickIntervalMs + 100L));
        faster.setOnClickListener(v -> setInterval(clickIntervalMs - 100L));

        TextView targetHint = makeLabel("Den lila Punkt auf die gewünschte Stelle ziehen.", 12, 0xFFACB7D3, false);
        LinearLayout.LayoutParams targetHintParams = matchWrap();
        targetHintParams.topMargin = dp(6);
        panel.addView(targetHint, targetHintParams);

        Button showTarget = makeButton("Klickpunkt zeigen", 0xFF303A52);
        LinearLayout.LayoutParams showTargetParams = matchWrap();
        showTargetParams.topMargin = dp(6);
        panel.addView(showTarget, showTargetParams);
        showTarget.setOnClickListener(v -> showTarget());

        Button minimize = makeButton("Menü einklappen", 0xFF303A52);
        LinearLayout.LayoutParams minimizeParams = matchWrap();
        minimizeParams.topMargin = dp(6);
        panel.addView(minimize, minimizeParams);
        minimize.setOnClickListener(v -> minimizePanel());

        panelView = panel;
        panelParams = new WindowManager.LayoutParams(
            dp(226), WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        panelParams.gravity = Gravity.TOP | Gravity.START;
        panelParams.x = dp(12);
        panelParams.y = dp(58);
        windowManager.addView(panelView, panelParams);
    }

    private void showTarget() {
        if (windowManager == null || targetView != null || clickerRunning) return;
        TextView target = new TextView(this);
        target.setText("⊙");
        target.setTextColor(Color.WHITE);
        target.setTextSize(29);
        target.setGravity(Gravity.CENTER);
        target.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        target.setBackground(roundRect(0xE87857E8, dp(40)));
        target.setElevation(dp(8));

        targetParams = new WindowManager.LayoutParams(
            targetWidth, targetHeight,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        targetParams.gravity = Gravity.TOP | Gravity.START;
        if (targetX == 0 && targetY == 0) {
            targetX = getResources().getDisplayMetrics().widthPixels / 2 - targetWidth / 2;
            targetY = getResources().getDisplayMetrics().heightPixels / 2 - targetHeight / 2;
        }
        targetParams.x = targetX;
        targetParams.y = targetY;

        target.setOnTouchListener(new View.OnTouchListener() {
            private float downRawX;
            private float downRawY;
            private int downX;
            private int downY;

            @Override public boolean onTouch(View view, MotionEvent event) {
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    downRawX = event.getRawX();
                    downRawY = event.getRawY();
                    downX = targetParams.x;
                    downY = targetParams.y;
                    return true;
                } else if (event.getAction() == MotionEvent.ACTION_MOVE) {
                    targetParams.x = downX + Math.round(event.getRawX() - downRawX);
                    targetParams.y = downY + Math.round(event.getRawY() - downRawY);
                    targetX = targetParams.x;
                    targetY = targetParams.y;
                    try {
                        windowManager.updateViewLayout(targetView, targetParams);
                    } catch (Exception ignored) {
                    }
                    return true;
                } else if (event.getAction() == MotionEvent.ACTION_UP) {
                    targetX = targetParams.x;
                    targetY = targetParams.y;
                    return true;
                }
                return true;
            }
        });

        targetView = target;
        windowManager.addView(targetView, targetParams);
    }

    private void showBubble() {
        if (windowManager == null || bubbleView != null) return;
        TextView bubble = new TextView(this);
        bubble.setText("AFK");
        bubble.setTextColor(Color.WHITE);
        bubble.setTextSize(12);
        bubble.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        bubble.setGravity(Gravity.CENTER);
        bubble.setBackground(roundRect(0xF07657E8, dp(28)));
        bubble.setElevation(dp(10));
        bubble.setOnClickListener(v -> restorePanel());

        bubbleView = bubble;
        bubbleParams = new WindowManager.LayoutParams(
            dp(56), dp(56),
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        bubbleParams.gravity = Gravity.TOP | Gravity.START;
        bubbleParams.x = dp(12);
        bubbleParams.y = dp(70);
        windowManager.addView(bubbleView, bubbleParams);
    }

    private void hideBubble() {
        if (bubbleView != null && windowManager != null) {
            try { windowManager.removeView(bubbleView); } catch (Exception ignored) {}
            bubbleView = null;
        }
    }

    private void minimizePanel() {
        if (panelView != null && windowManager != null) {
            try { windowManager.removeView(panelView); } catch (Exception ignored) {}
            panelView = null;
        }
        showBubble();
    }

    private void restorePanel() {
        hideBubble();
        if (panelView == null) createPanel();
        showTarget();
    }

    private void toggleSession() {
        if (!sessionRunning) {
            sessionRunning = true;
            sessionStartedAt = SystemClock.elapsedRealtime();
            afkButton.setText("AFK AUS");
            afkButton.setBackground(roundRect(0xFF8B3E4A, dp(12)));
        } else {
            accumulatedSessionMs += SystemClock.elapsedRealtime() - sessionStartedAt;
            sessionRunning = false;
            afkButton.setText("AFK AN");
            afkButton.setBackground(roundRect(0xFF246D54, dp(12)));
        }
        updateAfkTime();
    }

    private void updateAfkTime() {
        if (afkTimeText == null) return;
        long elapsed = accumulatedSessionMs;
        if (sessionRunning) elapsed += SystemClock.elapsedRealtime() - sessionStartedAt;
        long seconds = elapsed / 1000L;
        long hours = seconds / 3600L;
        long minutes = (seconds % 3600L) / 60L;
        long remainder = seconds % 60L;
        afkTimeText.setText(String.format(
            Locale.GERMANY, "AFK-Zeit %02d:%02d:%02d", hours, minutes, remainder
        ));
    }

    private void toggleClicker() {
        if (clickerRunning) {
            clickerRunning = false;
            handler.removeCallbacks(clickTicker);
            clickerButton.setText("Autoklicker START");
            clickerButton.setBackground(roundRect(0xFF7657E8, dp(12)));
            showTarget();
            return;
        }
        if (targetView != null) {
            targetX = targetParams.x;
            targetY = targetParams.y;
            try { windowManager.removeView(targetView); } catch (Exception ignored) {}
            targetView = null;
        }
        clickX = targetX + targetWidth / 2;
        clickY = targetY + targetHeight / 2;
        clickerRunning = true;
        clickerButton.setText("Autoklicker STOP");
        clickerButton.setBackground(roundRect(0xFF8B3E4A, dp(12)));
        handler.removeCallbacks(clickTicker);
        handler.post(clickTicker);
    }

    private void setInterval(long value) {
        clickIntervalMs = Math.max(200L, Math.min(5000L, value));
        if (intervalText != null) intervalText.setText(clickIntervalMs + " ms");
    }

    private Button makeButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextSize(13);
        button.setTextColor(Color.WHITE);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setPadding(dp(6), dp(3), dp(6), dp(3));
        button.setMinHeight(dp(42));
        button.setBackground(roundRect(color, dp(12)));
        return button;
    }

    private Button makeSmallButton(String text) {
        Button button = makeButton(text, 0xFF303A52);
        button.setTextSize(19);
        return button;
    }

    private TextView makeLabel(String text, int size, int color, boolean bold) {
        TextView label = new TextView(this);
        label.setText(text);
        label.setTextSize(size);
        label.setTextColor(color);
        label.setGravity(Gravity.CENTER);
        if (bold) label.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return label;
    }

    private GradientDrawable roundRect(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onAccessibilityEvent(android.view.accessibility.AccessibilityEvent event) {
        // No window text or screen contents are collected.
    }

    @Override
    public void onInterrupt() {
        stopClicker();
    }

    private void stopClicker() {
        clickerRunning = false;
        handler.removeCallbacks(clickTicker);
        if (clickerButton != null) {
            clickerButton.setText("Autoklicker START");
            clickerButton.setBackground(roundRect(0xFF7657E8, dp(12)));
        }
    }

    @Override
    public void onDestroy() {
        stopClicker();
        handler.removeCallbacks(timerTicker);
        hideBubble();
        if (targetView != null && windowManager != null) {
            try { windowManager.removeView(targetView); } catch (Exception ignored) {}
            targetView = null;
        }
        if (panelView != null && windowManager != null) {
            try { windowManager.removeView(panelView); } catch (Exception ignored) {}
            panelView = null;
        }
        super.onDestroy();
    }
}
JAVA

echo "Generated Anti-AFK Assistant with a manual AFK session timer and a user-controlled tap repeater. No screen capture or game-state analysis is implemented."
