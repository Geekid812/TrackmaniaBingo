// Medal text symbols taken from Ultimate Medals

namespace Medals {
	const string None = "\\$444" + Icons::Circle;
	const string Bronze = "\\$964" + Icons::Circle; 
	const string Silver = "\\$899" + Icons::Circle; 
	const string Gold = "\\$db4" + Icons::Circle;
	const string Author = "\\$071" + Icons::Circle;
}

string stringof(Medal medal) {
    if (medal == Medal::Author) return "Author";
    if (medal == Medal::Gold) return "Gold";
    if (medal == Medal::Silver) return "Silver";
    if (medal == Medal::Bronze) return "Bronze";
    return "None";
}

string symbolOf(Medal medal) {
    if (medal == Medal::Author) return Medals::Author;
    if (medal == Medal::Gold) return Medals::Gold;
    if (medal == Medal::Silver) return Medals::Silver;
    if (medal == Medal::Bronze) return Medals::Bronze;
    return Medals::None;
}

int objectiveOf(Medal medal, CGameCtnChallenge@ map) {
    if (medal == Medal::Author) return map.TMObjective_AuthorTime;
    if (medal == Medal::Gold) return map.TMObjective_GoldTime;
    if (medal == Medal::Silver) return map.TMObjective_SilverTime;
    if (medal == Medal::Bronze) return map.TMObjective_BronzeTime;
    return -1;
}
