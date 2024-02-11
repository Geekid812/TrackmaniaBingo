
class PollData {
    Poll poll;
    array<int> votes;
    uint64 startTime;

    PollData(Poll poll, array<int> votes, uint64 startTime) {
        this.poll = poll;
        this.votes = votes;
        this.startTime = startTime;
    }
}

namespace UIPoll {
    const int POLL_WINDOW_MARGIN = 12;
    const int POLL_WINDOW_HEIGHT = 100;
    const int ANIMATION_IN_MILLIS = 600;

    void RenderPoll(PollData@ data, uint pollStackIndex) {
        bool open = true;
        int targetWindowY = POLL_WINDOW_MARGIN + (POLL_WINDOW_HEIGHT + POLL_WINDOW_MARGIN) * pollStackIndex;        
        int currentY = int(Animation::GetProgress(Time::Now, data.startTime, ANIMATION_IN_MILLIS, Animation::Easing::CubicOut) * targetWindowY);

        UI::SetNextWindowPos(Draw::GetWidth() / 2, currentY, UI::Cond::Always, 0.5, 0.);
        Window::Create("##bingopoll" + data.poll.id, open, 500, POLL_WINDOW_HEIGHT, UI::WindowFlags::NoMove | UI::WindowFlags::NoResize | UI::WindowFlags::NoTitleBar);
        
        UITools::CenterText(data.poll.title);
        
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

        UI::End();
    }
}
