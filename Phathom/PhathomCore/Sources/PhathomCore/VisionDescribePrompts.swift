import Foundation

/// Shared on-device vision describe instructions (text GGUF + mmproj).
public enum VisionDescribePrompts {
    public static let defaultMediaDescribe = """
    Describe this image for a personal knowledge library.

    Write at most 2 sentences:
    1. Image type, main subject, and setting (max 25 words).
    2. Only if readable text exists: quote short titles, labels, or headings verbatim; paraphrase longer text (max 20 words). Omit sentence 2 entirely when there is no readable text.

    Do not include mood, aesthetics, camera details, or phrases like "This image shows". Plain text only.
    """
}
