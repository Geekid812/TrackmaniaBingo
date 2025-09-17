
class PollData {
    Poll poll;
    array<int> votes;
    uint64 startTime;
    uint64 expireTime;
    int resultIndex;

    PollData(Poll poll, array<int> votes, uint64 startTime) {
        this.poll = poll;
        this.votes = votes;
        this.startTime = startTime;
        this.expireTime = 0;
        this.resultIndex = -1;
    }

    bool IsOpen() { return this.resultIndex == -1; }
}

class NotifyData {

    string title;
    uint64 startTime;
    uint64 expireTime;
    UI::Texture @thumbnail;

    NotifyData(const string& in title,
               uint64 startTime,
               uint64 expireTime,
               UI::Texture @thumbnail = null) {
        this.title = title;
        this.startTime = startTime;
        this.expireTime = expireTime;
        @ this.thumbnail = thumbnail;
    }
}

namespace Poll {

    const uint64 POLL_EXPIRE_MILLIS = 5000;

    PollData @GetById(uint id) {
        for (uint i = 0; i < Polls.Length; i++) {
            if (Polls[i].poll.id == id)
                return Polls[i];
        }

        return null;
    }

    void CleanupExpiredToasts() {
        uint i = 0;
        while (i < Polls.Length) {
            if (Polls[i].expireTime != 0 && Polls[i].expireTime <= Time::Now)
                Polls.RemoveAt(i);
            else
                i++;
        }

        i = 0;
        while (i < Notifications.Length) {
            if (Notifications[i].expireTime != 0 && Notifications[i].expireTime <= Time::Now)
                Notifications.RemoveAt(i);
            else
                i++;
        }
    }
}

namespace UIPoll {
    const int POLL_WINDOW_MARGIN = 12;
    const int POLL_WINDOW_HEIGHT = 90;
    const int ANIMATION_IN_MILLIS = 600;
    const int TIMER_PROGRESS_HEIGHT = 8;
    const vec4 TIMER_PROGRESS_COLOR = vec4(.5, .5, .5, .5);
    const int NOTIFY_THUMBNAIL_SIZE = 48;

    void RenderPoll(PollData @data, uint stackIndex) {
        bool open = true;
        int targetWindowY =
            POLL_WINDOW_MARGIN + (POLL_WINDOW_HEIGHT + POLL_WINDOW_MARGIN) * stackIndex;
        int currentY =
            int(Animation::GetProgress(
                    Time::Now, data.startTime, ANIMATION_IN_MILLIS, Animation::Easing::CubicOut) *
                targetWindowY);

        UI::SetNextWindowPos(Draw::GetWidth() / 2, currentY, UI::Cond::Always, 0.5, 0.);
        Window::Create(
            "##bingopoll" + data.poll.id,
            open,
            Math::Max(500, int(Draw::MeasureString(data.poll.title, Font::Current()).x) + 100),
            POLL_WINDOW_HEIGHT,
            UI::WindowFlags::NoMove | UI::WindowFlags::NoResize | UI::WindowFlags::NoTitleBar |
                UI::WindowFlags::NoScrollbar);

        UITools::CenterText(data.poll.title);

        if (data.IsOpen())
            PresentPollChoices(data);
        else
            PresentWinnerChoice(data);

        DrawDeadlineProgress(data);
        UI::End();
    }

    void RenderNotify(NotifyData @data, uint stackIndex) {
        bool open = true;
        int targetWindowY =
            POLL_WINDOW_MARGIN + (POLL_WINDOW_HEIGHT + POLL_WINDOW_MARGIN) * stackIndex;
        int currentY =
            int(Animation::GetProgress(
                    Time::Now, data.startTime, ANIMATION_IN_MILLIS, Animation::Easing::CubicOut) *
                targetWindowY);

        UI::SetNextWindowPos(Draw::GetWidth() / 2, currentY, UI::Cond::Always, 0.5, 0.);
        Window::Create("##bingonotify" + stackIndex,
                       open,
                       500,
                       POLL_WINDOW_HEIGHT,
                       UI::WindowFlags::NoMove | UI::WindowFlags::AlwaysAutoResize |
                           UI::WindowFlags::NoTitleBar);

        UI::Dummy(vec2(500, 0));
        Layout::EndLabelAlign();

        string notifyTitle = data.title;
        UI::Font @font = Font::Current();
        Layout::MoveTo(
            Layout::GetPadding(UI::GetWindowSize().x,
                               Draw::MeasureString(notifyTitle, font, font.FontSize).x +
                                   (@data.thumbnail !is null ? NOTIFY_THUMBNAIL_SIZE : 0),
                               0.5));

        if (@data.thumbnail !is null) {
            UI::Image(data.thumbnail, vec2(NOTIFY_THUMBNAIL_SIZE, NOTIFY_THUMBNAIL_SIZE));
            UI::SameLine();
            Layout::MoveToY(UI::GetCursorPos().y +
                            (NOTIFY_THUMBNAIL_SIZE - UI::GetTextLineHeight()) / 4);
        }

        UI::Text(notifyTitle);

        UI::End();
    }

    void PresentPollChoices(PollData @data) {
        uint totalChoices = data.poll.choices.Length;
        float originY = UI::GetCursorPos().y;
        for (uint i = 0; i < totalChoices; i++) {
            Layout::MoveToY(originY);
            string buttonText = data.poll.choices[i].text;

            UIColor::Custom(data.poll.choices[i].color);
            float alignment = float(i + 1) / float(totalChoices + 1);
            if (totalChoices >= 3)
                alignment = 0.1 + 0.8 * (float(i) / float(totalChoices - 1));

            Layout::AlignButton(buttonText, alignment);
            if (UI::Button(buttonText)) {
                NetParams::PollId = data.poll.id;
                NetParams::PollChoiceIndex = i;
                startnew(Network::SubmitPollVote);
            }
            UIColor::Reset();

            string voteCount = tostring(data.votes[i]);
            Layout::AlignText(voteCount, alignment);
            UI::Text(voteCount);
        }
    }

    void PresentWinnerChoice(PollData @data) {
        UITools::CenterText("The result is: \\$fd8" + data.poll.choices[data.resultIndex].text);
    }

    void DrawDeadlineProgress(PollData @data) {
        UI::DrawList @drawList = UI::GetWindowDrawList();
        float windowWidth = UI::GetWindowSize().x;
        uint64 timePassedSinceStart = Time::Now - data.startTime;

        float progressScale =
            1. - Math::Clamp(float(timePassedSinceStart) / float(data.poll.duration), 0., 1.);
        vec2 globalPosition =
            vec2(0., POLL_WINDOW_HEIGHT - TIMER_PROGRESS_HEIGHT) + UI::GetWindowPos();
        drawList.AddRectFilled(vec4(globalPosition.x,
                                    globalPosition.y,
                                    windowWidth * progressScale,
                                    TIMER_PROGRESS_HEIGHT),
                               TIMER_PROGRESS_COLOR);
    }

    void NotifyToast(const string& in title,
                     uint64 duration = Poll::POLL_EXPIRE_MILLIS,
                     UI::Texture @thumbnail = null) {
        NotifyData notifyData(title, Time::Now, Time::Now + duration, thumbnail);
        Notifications.InsertLast(notifyData);
    }

    void ClearAllPollsAndNotifications() {
        logtrace("[UIPolls::ClearAllPollsAndNotifications] All toasts were removed.");
        Polls.Resize(0);
        Notifications.Resize(0);
    }
}
