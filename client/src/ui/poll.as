
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

    bool IsOpen() {
        return this.resultIndex == -1;
    }
}

namespace Poll {
    const uint64 POLL_EXPIRE_MILLIS = 5000;

    PollData@ GetById(uint id) {
        for (uint i = 0; i < Polls.Length; i++) {
            if (Polls[i].poll.id == id) return Polls[i];
        }

        return null;
    }

    void CleanupExpiredPolls() {
        uint i = 0;
        while (i < Polls.Length) {
            if (Polls[i].expireTime != 0 && Polls[i].expireTime <= Time::Now)
                Polls.RemoveAt(i);
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

    void RenderPoll(PollData@ data, uint pollStackIndex) {
        bool open = true;
        int targetWindowY = POLL_WINDOW_MARGIN + (POLL_WINDOW_HEIGHT + POLL_WINDOW_MARGIN) * pollStackIndex;        
        int currentY = int(Animation::GetProgress(Time::Now, data.startTime, ANIMATION_IN_MILLIS, Animation::Easing::CubicOut) * targetWindowY);

        UI::SetNextWindowPos(Draw::GetWidth() / 2, currentY, UI::Cond::Always, 0.5, 0.);
        Window::Create("##bingopoll" + data.poll.id, open, 500, POLL_WINDOW_HEIGHT, UI::WindowFlags::NoMove | UI::WindowFlags::NoResize | UI::WindowFlags::NoTitleBar);
        
        UITools::CenterText(data.poll.title);
        
        if (data.IsOpen())
            PresentPollChoices(data);
        else
            PresentWinnerChoice(data);


        DrawDeadlineProgress(data);
        UI::End();
    }

    void PresentPollChoices(PollData@ data) {
        uint totalChoices = data.poll.choices.Length;
        float originY = UI::GetCursorPos().y;
        for (uint i = 0; i < totalChoices; i++) {
            Layout::MoveToY(originY);
            string buttonText = data.poll.choices[i].text;

            UIColor::Custom(data.poll.choices[i].color);
            float alignment = float(i + 1) / float(totalChoices + 1);
            Layout::AlignButton(buttonText, alignment);
            if (UI::Button(buttonText)) {

            }
            UIColor::Reset();

            string voteCount = tostring(data.votes[i]);
            Layout::AlignText(voteCount, alignment);
            UI::Text(voteCount);
        }
    }

    void PresentWinnerChoice(PollData@ data) {
        UITools::CenterText("The result is: \\$fd8" + data.poll.choices[data.resultIndex].text);
    }

    void DrawDeadlineProgress(PollData@ data) {
        UI::DrawList@ drawList = UI::GetWindowDrawList();
        float windowWidth = UI::GetWindowSize().x;
        uint64 timePassedSinceStart = Time::Now - data.startTime;

        float progressScale = 1. - Math::Clamp(float(timePassedSinceStart) / float(data.poll.duration), 0., 1.);
        vec2 globalPosition = vec2(0., POLL_WINDOW_HEIGHT - TIMER_PROGRESS_HEIGHT) + UI::GetWindowPos();
        drawList.AddRectFilled(vec4(globalPosition.x, globalPosition.y, windowWidth * progressScale, TIMER_PROGRESS_HEIGHT), TIMER_PROGRESS_COLOR);
    }
}
