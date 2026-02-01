import * as dist from "../dist/index";

describe("New Features", () => {
    test("Roll Query with Default", () => {
        const roller = new dist.DiceRoller(() => 0); 
        expect(roller.rollValue("?{Dice|5}")).toBe(5);
    });

    test("Roll Query with Context", () => {
        const ctx = { "Attack": "10" };
        const roller = new dist.DiceRoller(() => 0, 1000, ctx);
        expect(roller.rollValue("?{Attack|5}")).toBe(10);
    });

    test("Storypath (10=2, 8-9=1) using Generic Syntax", () => {
        const seq = [0.9, 0.8, 0.7, 0.0]; 
        let i = 0;
        const roller = new dist.DiceRoller(() => seq[i++]);
        
        // 4d10ds10>7 (ds10 is part of the die modifiers, >7 is the comparison)
        const result: any = roller.roll("4d10ds10>7");
        
        expect(result.rolls[0].value).toBe(2); // 10
        expect(result.rolls[1].value).toBe(1); // 9
        expect(result.rolls[2].value).toBe(1); // 8
        expect(result.rolls[3].value).toBe(0); // 1
        expect(result.value).toBe(4);
    });

    test("Chronicles of Darkness (Explode 10, Hit 8+)", () => {
        // Use grouping to separate Explode from Success Check
        // {1d10!} means "Roll 1d10, explode on 10".
        // >7 applies to the group results? No, group success check sums them?
        // Wait, {5d6}>8 sums 5d6 then checks.
        // We want individual success counting.
        // 5d10>7 counts successes.
        // 5d10!>7 parses as explode>7.
        
        // Solution: Use specific explode target to be explicit?
        // 1d10!10>7 (Explode on 10, Success >7).
        // Does grammar allow this?
        // ExplodeRoll = "!" target:TargetMod?
        // TargetMod = mod value | value.
        // If I write !10, it explodes on 10.
        // Then >7 follows.
        // Let's try 1d10!10>7.
        
        const seq = [0.9, 0.7]; 
        let i = 0;
        const roller = new dist.DiceRoller(() => {
            if (i >= seq.length) return 0;
            return seq[i++];
        });

        const result: any = roller.roll("1d10!10>7");
        
        expect(result.rolls.length).toBe(2); // 10 exploded
        expect(result.rolls[0].roll).toBe(10);
        expect(result.rolls[1].roll).toBe(8);
        expect(result.value).toBe(2); // 2 successes
    });
});