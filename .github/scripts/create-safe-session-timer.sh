#!/usr/bin/env bash
set -euo pipefail

APP="source/app/src/main"
rm -rf "$APP/java" "$APP/kotlin" "$APP/assets" "$APP/raw"
mkdir -p "$APP/java/de/antiafk/assistant"

cat > "$APP/AndroidManifest.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="false"
        android:label="Session Timer"
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
    </application>
</manifest>
XML

cat > "$APP/java/de/antiafk/assistant/MainActivity.java" <<'JAVA'
package de.antiafk.assistant;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.Locale;

public class MainActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView timerText;
    private TextView statusText;
    private Button toggleButton;
    private long selectedDurationMs = 30L * 60L * 1000L;
    private long remainingMs = selectedDurationMs;
    private long endAtElapsedMs = 0L;
    private boolean running = false;

    private final Runnable ticker = new Runnable() {
        @Override public void run() {
            if (!running) return;
            remainingMs = Math.max(0L, endAtElapsedMs - SystemClock.elapsedRealtime());
            if (remainingMs == 0L) {
                running = false;
                statusText.setText("Zeit ist um – gönn dir eine Pause.");
                toggleButton.setText("Start");
            }
            updateTimer();
            if (running) handler.postDelayed(this, 1000L);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.rgb(13, 16, 27));
        getWindow().setNavigationBarColor(Color.rgb(13, 16, 27));

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(Color.rgb(13, 16, 27));

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(22), dp(30), dp(22), dp(28));
        scroll.addView(page);
        setContentView(scroll);

        TextView eyebrow = text("PERSONAL SESSION TOOL", 12, 0xFF9CA8C8, true);
        eyebrow.setLetterSpacing(0.12f);
        page.addView(eyebrow, matchWrap());

        TextView title = text("Session Timer", 32, Color.WHITE, true);
        LinearLayout.LayoutParams titleParams = matchWrap();
        titleParams.topMargin = dp(8);
        page.addView(title, titleParams);

        TextView subtitle = text("Behalte deine eigene Spielzeit im Blick.", 15, 0xFFB8C0D6, false);
        LinearLayout.LayoutParams subtitleParams = matchWrap();
        subtitleParams.topMargin = dp(5);
        page.addView(subtitle, subtitleParams);

        LinearLayout timerCard = new LinearLayout(this);
        timerCard.setOrientation(LinearLayout.VERTICAL);
        timerCard.setGravity(Gravity.CENTER);
        timerCard.setPadding(dp(18), dp(26), dp(18), dp(26));
        timerCard.setBackground(background(0xFF1B2133, 26));
        LinearLayout.LayoutParams cardParams = matchWrap();
        cardParams.topMargin = dp(28);
        page.addView(timerCard, cardParams);

        TextView label = text("VERBLEIBENDE ZEIT", 12, 0xFF9CA8C8, true);
        label.setLetterSpacing(0.1f);
        timerCard.addView(label, wrapWrap());

        timerText = text("30:00", 56, Color.WHITE, true);
        timerText.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        LinearLayout.LayoutParams timerParams = wrapWrap();
        timerParams.topMargin = dp(7);
        timerCard.addView(timerText, timerParams);

        statusText = text("Bereit für deine Sitzung.", 14, 0xFFB8C0D6, false);
        LinearLayout.LayoutParams statusParams = wrapWrap();
        statusParams.topMargin = dp(8);
        timerCard.addView(statusText, statusParams);

        TextView presetHeading = text("TIMER-LÄNGE", 13, 0xFF9CA8C8, true);
        LinearLayout.LayoutParams presetHeadingParams = matchWrap();
        presetHeadingParams.topMargin = dp(27);
        page.addView(presetHeading, presetHeadingParams);

        LinearLayout presets = new LinearLayout(this);
        presets.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams presetsParams = matchWrap();
        presetsParams.topMargin = dp(12);
        page.addView(presets, presetsParams);
        addPreset(presets, 15);
        addPreset(presets, 30);
        addPreset(presets, 45);
        addPreset(presets, 60);

        toggleButton = makeButton("Start", 0xFF7657E8, Color.WHITE, true);
        LinearLayout.LayoutParams toggleParams = matchWrap();
        toggleParams.topMargin = dp(24);
        page.addView(toggleButton, toggleParams);
        toggleButton.setOnClickListener(v -> toggleTimer());

        Button reset = makeButton("Zurücksetzen", 0xFF252C40, 0xFFE4E8F3, false);
        LinearLayout.LayoutParams resetParams = matchWrap();
        resetParams.topMargin = dp(10);
        page.addView(reset, resetParams);
        reset.setOnClickListener(v -> resetTimer());

        TextView note = text(
            "Der Timer erinnert dich an deine Zeit. Er steuert keine Spiele, bewegt keine Spielfigur und drückt keine Tasten.",
            13, 0xFF929DB8, false
        );
        note.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams noteParams = matchWrap();
        noteParams.topMargin = dp(25);
        page.addView(note, noteParams);

        updateTimer();
    }

    private void addPreset(LinearLayout row, int minutes) {
        Button button = makeButton(minutes + " min", 0xFF252C40, 0xFFE4E8F3, false);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(48), 1f);
        if (minutes > 15) params.leftMargin = dp(7);
        row.addView(button, params);
        button.setOnClickListener(v -> {
            if (running) return;
            selectedDurationMs = minutes * 60L * 1000L;
            remainingMs = selectedDurationMs;
            statusText.setText("Timer auf " + minutes + " Minuten gestellt.");
            updateTimer();
        });
    }

    private void toggleTimer() {
        if (running) {
            remainingMs = Math.max(0L, endAtElapsedMs - SystemClock.elapsedRealtime());
            running = false;
            handler.removeCallbacks(ticker);
            statusText.setText("Pausiert.");
            toggleButton.setText("Weiter");
        } else {
            if (remainingMs <= 0L) remainingMs = selectedDurationMs;
            endAtElapsedMs = SystemClock.elapsedRealtime() + remainingMs;
            running = true;
            statusText.setText("Timer läuft.");
            toggleButton.setText("Pause");
            handler.removeCallbacks(ticker);
            handler.post(ticker);
        }
        updateTimer();
    }

    private void resetTimer() {
        running = false;
        handler.removeCallbacks(ticker);
        remainingMs = selectedDurationMs;
        statusText.setText("Timer zurückgesetzt.");
        toggleButton.setText("Start");
        updateTimer();
    }

    private void updateTimer() {
        long totalSeconds = Math.max(0L, remainingMs / 1000L);
        long minutes = totalSeconds / 60L;
        long seconds = totalSeconds % 60L;
        timerText.setText(String.format(Locale.GERMANY, "%02d:%02d", minutes, seconds));
    }

    private Button makeButton(String value, int fill, int textColor, boolean bold) {
        Button button = new Button(this);
        button.setText(value);
        button.setTextColor(textColor);
        button.setTextSize(15);
        button.setAllCaps(false);
        button.setTypeface(Typeface.create("sans-serif", bold ? Typeface.BOLD : Typeface.NORMAL));
        button.setPadding(dp(10), dp(7), dp(10), dp(7));
        button.setMinHeight(dp(48));
        button.setBackground(background(fill, 16));
        return button;
    }

    private TextView text(String value, int size, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setGravity(Gravity.CENTER);
        view.setTypeface(Typeface.create("sans-serif", bold ? Typeface.BOLD : Typeface.NORMAL));
        return view;
    }

    private GradientDrawable background(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radius));
        return drawable;
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
    }

    private LinearLayout.LayoutParams wrapWrap() {
        return new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacks(ticker);
        super.onDestroy();
    }
}
JAVA

echo "Created a timer-only Android app: no screen capture, accessibility service, game input, or automated gameplay."
