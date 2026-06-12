import KadiEngine

/// Resolves a `GameAction` for a CPU-controlled player, falling back through
/// progressively safer choices if `agent`'s first choice doesn't pass
/// `GameEngine.validateAction` (e.g. an unplayable declared-Kadi chain involving a Joker —
/// see `docs/PHASE2_PLAN.md`).
enum CpuActionResolver {
    static func resolve(agent: CpuAgent, state: GameState, playerIndex: Int) -> GameAction {
        let action = agent.chooseAction(state: state, playerIndex: playerIndex)
        if GameEngine.validateAction(state, action) == nil {
            return action
        }

        let fallback: GameAction = state.isDrawStackActive
            ? agent.drawStackResponse(state: state, playerIndex: playerIndex)
            : agent.normalPlay(state: state, playerIndex: playerIndex)
        if GameEngine.validateAction(state, fallback) == nil {
            return fallback
        }

        if GameEngine.validateAction(state, .pass) == nil {
            return .pass
        }
        if GameEngine.validateAction(state, .drawStack) == nil {
            return .drawStack
        }
        return fallback
    }
}
