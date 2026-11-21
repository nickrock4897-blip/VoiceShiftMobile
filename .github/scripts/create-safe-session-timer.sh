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
            android:name=".SessionOverlayService"
            android:label="Anti-AFK Assistant – Sitzungsmenü"
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
    android:canRetrieveWindowContent="false" />
XML

cat > "$APP/res/values/strings.xml" <<'XML'
<resources>
    <string name="app_name">Anti-AFK Assistant</string>
    <string name="accessibility_service_description">Zeigt ein schwebendes Sitzungsmenü mit AFK-Start, AFK-Stopp und Zeitmessung. Liest keine Bildschirminhalte und steuert keine anderen Apps.</string>
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
        description.setText("Aktiviere das Sitzungsmenü in Androids Bedienungshilfen. Danach kannst du es über anderen Apps einblenden.");
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
        note.setText("Das schwebende Menü enthält AFK AN, AFK AUS und eine laufende Zeitanzeige. Die App liest keine Bildschirminhalte und führt keine Eingaben in Spielen oder anderen Apps aus.");
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
        String component = new ComponentName(this, SessionOverlayService.class)
            .flattenToString();
        boolean active = !TextUtils.isEmpty(enabled) && enabled.toLowerCase().contains(
            component.toLowerCase()
        );
        status.setText(active
            ? "Sitzungsmenü ist eingeschaltet."
            : "Sitzungsmenü ist noch ausgeschaltet. Aktiviere den Dienst in den Einstellungen.");
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

cat > "$APP/java/de/antiafk/assistant/SessionOverlayService.java" <<'JAVA'
package de.antiafk.assistant;

import android.accessibilityservice.AccessibilityService;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Locale;

public class SessionOverlayService extends AccessibilityService {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WindowManager windowManager;
    private View panelView;
    private View bubbleView;
    private TextView timerText;
    private Button startButton;
    private Button stopButton;

    private boolean sessionRunning = false;
    private long sessionStartedAt = 0L;
    private long accumulatedSessionMs = 0L;

    private final Runnable timerTicker = new Runnable() {
        @Override public void run() {
            updateTimer();
            handler.postDelayed(this, 1000L);
        }
    };

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        createPanel();
        handler.removeCallbacks(timerTicker);
        handler.post(timerTicker);
    }

    private void createPanel() {
        if (panelView != null || windowManager == null) return;

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(13), dp(12), dp(13), dp(13));
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

        timerText = new TextView(this);
        timerText.setTextColor(0xFFEFF2FF);
        timerText.setTextSize(22);
        timerText.setGravity(Gravity.CENTER);
        timerText.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        panel.addView(timerText, matchWrap());

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams actionsParams = matchWrap();
        actionsParams.topMargin = dp(9);
        panel.addView(actions, actionsParams);

        startButton = makeButton("AFK AN", 0xFF246D54);
        LinearLayout.LayoutParams actionButtonParams = new LinearLayout.LayoutParams(0, dp(46), 1f);
        actions.addView(startButton, actionButtonParams);
        startButton.setOnClickListener(v -> startSession());

        stopButton = makeButton("AFK AUS", 0xFF8B3E4A);
        LinearLayout.LayoutParams stopParams = new LinearLayout.LayoutParams(0, dp(46), 1f);
        stopParams.leftMargin = dp(8);
        actions.addView(stopButton, stopParams);
        stopButton.setOnClickListener(v -> stopSession());

        Button minimize = makeButton("Menü einklappen", 0xFF303A52);
        LinearLayout.LayoutParams minimizeParams = matchWrap();
        minimizeParams.topMargin = dp(8);
        panel.addView(minimize, minimizeParams);
        minimize.setOnClickListener(v -> minimizePanel());

        panelView = panel;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            dp(230), WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.START;
        params.x = dp(12);
        params.y = dp(58);
        windowManager.addView(panelView, params);
        updateTimer();
    }

    private void minimizePanel() {
        if (panelView != null && windowManager != null) {
            try { windowManager.removeView(panelView); } catch (Exception ignored) {}
            panelView = null;
        }
        showBubble();
    }

    private void showBubble() {
        if (bubbleView != null || windowManager == null) return;
        TextView bubble = new TextView(this);
        bubble.setText("AFK");
        bubble.setTextColor(Color.WHITE);
        bubble.setTextSize(12);
        bubble.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        bubble.setGravity(Gravity.CENTER);
        bubble.setBackground(roundRect(0xF07657E8, dp(28)));
        bubble.setElevation(dp(10));
        bubble.setOnClickListener(v -> {
            removeBubble();
            createPanel();
        });

        bubbleView = bubble;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            dp(56), dp(56),
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.START;
        params.x = dp(12);
        params.y = dp(70);
        windowManager.addView(bubbleView, params);
    }

    private void removeBubble() {
        if (bubbleView != null && windowManager != null) {
            try { windowManager.removeView(bubbleView); } catch (Exception ignored) {}
            bubbleView = null;
        }
    }

    private void startSession() {
        if (sessionRunning) return;
        accumulatedSessionMs = 0L;
        sessionStartedAt = SystemClock.elapsedRealtime();
        sessionRunning = true;
        updateTimer();
    }

    private void stopSession() {
        if (!sessionRunning) return;
        accumulatedSessionMs += SystemClock.elapsedRealtime() - sessionStartedAt;
        sessionRunning = false;
        updateTimer();
    }

    private void updateTimer() {
        if (timerText == null) return;
        long elapsed = accumulatedSessionMs;
        if (sessionRunning) elapsed += SystemClock.elapsedRealtime() - sessionStartedAt;
        long seconds = Math.max(0L, elapsed / 1000L);
        long hours = seconds / 3600L;
        long minutes = (seconds % 3600L) / 60L;
        long remainder = seconds % 60L;
        timerText.setText(String.format(
            Locale.GERMANY, "AFK-Zeit\\n%02d:%02d:%02d", hours, minutes, remainder
        ));
    }

    private Button makeButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextSize(13);
        button.setTextColor(Color.WHITE);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setPadding(dp(5), dp(3), dp(5), dp(3));
        button.setMinHeight(dp(44));
        button.setBackground(roundRect(color, dp(12)));
        return button;
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
        // Events are intentionally not inspected.
    }

    @Override
    public void onInterrupt() {
        stopSession();
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(timerTicker);
        removeBubble();
        if (panelView != null && windowManager != null) {
            try { windowManager.removeView(panelView); } catch (Exception ignored) {}
            panelView = null;
        }
        super.onDestroy();
    }
}
JAVA

echo "Generated a floating session timer only; no screen reading and no automated input."
