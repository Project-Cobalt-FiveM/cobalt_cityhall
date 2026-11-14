---@class TheoryQuestion
---@field question string
---@field answers string[]
---@field correct integer the index of the right answer in `answers`

---@type TheoryQuestion[]
return {
    {
        question = 'What does a red traffic light mean?',
        answers = { 'Stop and wait for green', 'Speed up to clear the junction', 'Slow down and carry on', 'Sound the horn and go' },
        correct = 1,
    },
    {
        question = 'An ambulance comes up behind you with its siren on. What do you do?',
        answers = { 'Keep driving at the same speed', 'Pull over to the right and let it pass', 'Brake hard where you are', 'Race it to the next junction' },
        correct = 2,
    },
    {
        question = 'Who has priority at a marked pedestrian crossing?',
        answers = { 'The fastest vehicle', 'Buses and taxis', 'Pedestrians on the crossing', 'Whoever arrived first' },
        correct = 3,
    },
    {
        question = 'When must your headlights be on?',
        answers = { 'Only on the freeway', 'Only when it rains', 'Never inside the city', 'At night and when it is hard to see' },
        correct = 4,
    },
    {
        question = 'Can you drive after drinking alcohol?',
        answers = { 'No. Never drink and drive', 'Yes, if you feel fine', 'Yes, for short trips', 'Yes, at night when roads are quiet' },
        correct = 1,
    },
}
