/// Keys used in the Bean Count meta data
enum MetaDataKeys {
    /// Key used for the importer type
    static let importerType = "importer-type"
    /// Value for the importer type
    static let importerTypeValue = "rogers"
    /// Key used to find accounts by the last 4 digits
    static let lastFour = "last-four"
    /// Key used to mark and find transactions
    static let activityId = "rogers-bank-id"
    /// Optional metadata key on the destination account for Rogers payments
    static let payment = "rogers-payment"
    /// Optional metadata key on the destination account for Rogers over limit fees
    static let overlimitFee = "rogers-overlimit-fee"
}
