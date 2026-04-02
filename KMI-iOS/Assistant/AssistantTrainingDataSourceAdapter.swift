import Foundation

final class AssistantTrainingDataSourceAdapter: AssistantTrainingDataSource {
    private let provider: () -> [TrainingRow]

    init(provider: @escaping () -> [TrainingRow]) {
        self.provider = provider
    }

    func allTrainings() -> [TrainingRow] {
        provider()
    }
}
